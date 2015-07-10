class Ronron extends Run
    constructor: (dataService) ->
        # dataService.get('builders/1/builds/1', {builderid: 1}).then (a) -> console.log a

class DBStores extends Constant
    constructor: ->
        return {
            paths: '&[path+query],path,query,tracked,lastActive'
        }

class IndexedDB extends Service
    constructor: ($log, $window, $injector, $q, dataUtilsService, DBSTORES, SPECIFICATION) ->
        return new class IndexedDBService
            constructor: ->
                @db = new $window.Dexie('BBCache')
                dbStores = angular.extend {},
                    @processSpecification(SPECIFICATION), DBSTORES
                @db.version(1).stores(dbStores)

                # global db error handler
                @db.on 'error', (e) -> $log.error(e)

                @db.open()

            get: (url, query = {}) ->
                [tableName, q, id] = @processUrl(url)
                angular.extend query, q

                table = @db[tableName]

                @db.transaction 'r', table, =>

                    # convert promise to $q implementation
                    if id? then return $q.resolve table.get(id)

                    # TODO note: this takes almost a second
                    promise = table.toArray()

                    # 1. filtering
                    filters = []
                    for fieldAndOperator, value of query
                        if ['field', 'limit', 'offset', 'order'].indexOf(fieldAndOperator) < 0
                            filters[fieldAndOperator] = value
                    promise = @filter(promise, filters)

                    # 2. sorting
                    order = query?.order
                    promise = @sort(promise, order)

                    # 3. pagination
                    offset = query?.offset
                    limit = query?.limit
                    promise = @paginate(promise, offset, limit)

                    # TODO 4. properties
                    property = query?.property
                    promise = @properties(promise, property)

                    # 5. fields
                    fields = query?.field
                    promise = @fields(promise, fields)

                    return promise

            filter: (promise, filters) ->
                $q (resolve, reject) ->
                    promise.then (array) ->
                        resolve array.filter (v) ->
                            for fieldAndOperator, value of filters
                                [field, operator] = fieldAndOperator.split('__')
                                switch operator
                                    when 'ne' then cmp = v[field] != value
                                    when 'lt' then cmp = v[field] <  value
                                    when 'le' then cmp = v[field] <= value
                                    when 'gt' then cmp = v[field] >  value
                                    when 'ge' then cmp = v[field] >= value
                                    else           cmp = v[field] == value
                                if !cmp then return false
                            return true

                # promise = collection.and (v) ->
                #     for fieldAndOperator, value of filters
                #         [field, operator] = fieldAndOperator.split('__')
                #         switch operator
                #             when 'ne' then cmp = v[field] != value
                #             when 'lt' then cmp = v[field] <  value
                #             when 'le' then cmp = v[field] <= value
                #             when 'gt' then cmp = v[field] >  value
                #             when 'ge' then cmp = v[field] >= value
                #             else           cmp = v[field] == value
                #         if !cmp then return false
                #     return true
                # .toArray()

                # convert promise to $q implementation
                # $q.resolve(promise)

            sort: (promise, order) ->
                $q (resolve, reject) ->
                    promise.then (array) ->
                        compare = (property) ->
                            if property[0] is '-'
                                property = property[1..]
                                reverse = true

                            return (a, b) ->
                                if reverse then [a, b] = [b, a]

                                if a[property] < b[property] then -1
                                else if a[property] > b[property] then 1
                                else 0

                        if angular.isString(order)
                            array.sort compare(order)
                        else if angular.isArray(order)
                            array.sort (a, b) ->
                                for o in query.order
                                    f = compare(o)(a, b)
                                    if f then return f
                                return 0

                        resolve(array)

            paginate: (promise, offset, limit) ->
                $q (resolve, reject) ->
                    promise.then (array) ->
                        offset ?= 0
                        if offset >= array.length
                            resolve([])
                            return

                        if not limit? or offset + limit > array.length
                            end = array.length
                        else
                            end = offset + limit - 1

                        resolve(array[offset..end])

            properties: (promise, properties) ->
                $q (resolve, reject) ->
                    promise.then (array) ->
                        resolve(array)

            fields: (promise, fields) ->
                $q (resolve, reject) ->
                    promise.then (array) ->
                        if not fields?
                            resolve(array)
                            return

                        if not angular.isArray(fields) then fields = [fields]

                        for element in array
                            for key of element
                                if key not in fields
                                    delete element[key]

                        resolve(array)

            numberOrString: (str) ->
                number = parseInt str, 10
                if !isNaN(number) then number else str

            processUrl: (url) ->
                [root, id, path...] = url.split('/')
                specification = SPECIFICATION[root]
                query = {}
                if path.length == 0
                    id = @numberOrString(id)
                    if angular.isString(id) and specification.identifier
                        query[specification.identifier] = id
                        id = null
                    return [root, query, id]

                pathString = path.join('/')
                match = specification.paths.filter (p) ->
                    replaced = p
                        .replace ///#{SPECIFICATION.FIELDTYPES.IDENTIFIER}\:\w+///g, '\\d+'
                        .replace ///#{SPECIFICATION.FIELDTYPES.NUMBER}\:\w+///g, '\\w+'
                    ///^#{replaced}$///.test(pathString)
                .pop()
                if not match?
                    throw new Error("No child path (#{path.join('/')}) found for root (#{endpoint})")

                id = null
                last = match.split('/').pop()
                if last.indexOf(':') > -1
                    [fieldType, fieldName] = last.split(':')
                    fieldValue = path.pop()
                    if fieldName.indexOf('id', fieldName.length - 'id'.length) != -1
                        id = @numberOrString(fieldValue)
                    else
                        query[fieldName] = @numberOrString(fieldValue)
                tableName = path.pop()

                return [tableName, query, id]

            processSpecification: ->
                # IndexedDB tables
                stores = {}
                for name, s of SPECIFICATION
                    if angular.isArray(s.fields)
                        a = s.fields[..]
                        i = a.indexOf(s.id)
                        if i > -1 then a[i] = "&#{a[i]}"
                        else a.push('++id')
                        stores[name] = a.join(',')
                return stores
