class DBStores extends Constant
    constructor: ->
        return {
            paths: '&[path+query],path,query,lastActive'
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

                @db.open().catch (e) -> $log.error(e)

            get: (url, query = {}) ->
                [tableName, q, id] = @processUrl(url)
                angular.extend query, q

                table = @db[tableName]

                @db.transaction 'r', table, =>

                    # convert promise to $q implementation
                    if id? then return $q.resolve table.get(id)

                    $q (resolve, reject) =>
                        table.toArray().then (array) =>
                            array = array.map (e) ->
                                for k, v of e
                                    try
                                        e[k] = angular.fromJson(v)
                                    catch error then # ignore
                                return e

                            # 1. filtering
                            filters = []
                            for fieldAndOperator, value of query
                                if ['field', 'limit', 'offset', 'order'].indexOf(fieldAndOperator) < 0
                                    filters[fieldAndOperator] = value
                            array = @filter(array, filters)

                            # 2. sorting
                            order = query?.order
                            array = @sort(array, order)

                            # 3. pagination
                            offset = query?.offset
                            limit = query?.limit
                            array = @paginate(array, offset, limit)

                            # TODO 4. properties
                            property = query?.property
                            array = @properties(array, property)

                            # 5. fields
                            fields = query?.field
                            array = @fields(array, fields)

                            resolve(array)

            filter: (array, filters) ->
                array.filter (v) ->
                    for fieldAndOperator, value of filters
                        if ['on', 'true', 'yes'].indexOf(value) > -1 then value = true
                        else if ['off', 'false', 'no'].indexOf(value) > -1 then value = false
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

            sort: (array, order) ->
                compare = (property) ->
                    if property[0] is '-'
                        property = property[1..]
                        reverse = true

                    return (a, b) ->
                        if reverse then [a, b] = [b, a]

                        if a[property] < b[property] then -1
                        else if a[property] > b[property] then 1
                        else 0

                copy = array[..]
                if angular.isString(order)
                    copy.sort compare(order)
                else if angular.isArray(order)
                    copy.sort (a, b) ->
                        for o in order
                            f = compare(o)(a, b)
                            if f then return f
                        return 0

                return copy

            paginate: (array, offset, limit) ->
                offset ?= 0
                if offset >= array.length
                    return []

                if not limit? or offset + limit > array.length
                    end = array.length
                else
                    end = offset + limit - 1

                return array[offset..end]

            # TODO
            properties: (array, properties) ->
                return array

            fields: (array, fields) ->
                if not fields?
                    return array

                if not angular.isArray(fields) then fields = [fields]

                for element in array
                    for key of element
                        if key not in fields
                            delete element[key]

                return array

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
                        .replace ///#{SPECIFICATION.FIELDTYPES.IDENTIFIER}\:\w+///g, '\\w+'
                        .replace ///#{SPECIFICATION.FIELDTYPES.NUMBER}\:\w+///g, '\\d+'
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

            processSpecification: (specification) ->
                # IndexedDB tables
                stores = {}
                for name, s of specification
                    if angular.isArray(s.fields)
                        a = s.fields[..]
                        i = a.indexOf(s.id)
                        if i > -1 then a[i] = "&#{a[i]}"
                        else a.unshift('++id')
                        stores[name] = a.join(',')
                return stores
