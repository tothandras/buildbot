class Tabex extends Service
    constructor: ($log, $window, $q, $timeout, socketService, restService, dataUtilsService, indexedDBService, SPECIFICATION) ->
        return new class TabexService
            CHANNELS =
                MASTER: '!sys.master'
                REFRESH: '!sys.channels.refresh'

            ROLES =
                MASTER: 'bb.role.master'
                SLAVE: 'bb.role.slave'

            EVENTS =
                READY: 'bb.event.ready'
                UPDATE: 'bb.event.update'
                NEW: 'bb.event.new'
            EVENTS: EVENTS

            client: $window.tabex.client()

            constructor: ->
                # the message handler will be called on update messages
                socketService.onMessage = @messageHandler
                # the close handler will be called on close event
                # we need to resend the startConsuming messages for
                # every tracked channels
                socketService.onClose = @closeHandler

                @initialRoleDeferred = $q.defer()
                @initialRole = @initialRoleDeferred.promise

                @client.on CHANNELS.MASTER, @masterHandler
                @client.on CHANNELS.REFRESH, @refreshHandler

                $window.onunload = $window.onbeforeunload = (e) =>
                    @activatePaths()
                    return null

            masterHandler: (data) =>
                if data.node_id is data.master_id
                    @role = ROLES.MASTER
                    @initialRoleDeferred.resolve()
                    socketService.open()
                else
                    @role = ROLES.SLAVE
                    @initialRoleDeferred.resolve()
                    socketService.close()

            refreshHandler: (data) =>
                # wait for the role to be determined
                @initialRole.then =>
                    if @role is ROLES.MASTER then @masterRefreshHandler(data)

            debounceTimeout: 100
            # path: [query]
            trackedPaths: {}
            masterRefreshHandler: (data) ->
                # debounce logic
                if @timeoutPromise? then $timeout.cancel(@timeoutPromise)
                @timeoutPromise = $timeout =>
                    @activatePaths().then =>

                        # filter channels by system channels (starts with `!sys.`)
                        channels = data.channels.filter (c) -> c.indexOf('!sys.') != 0

                        paths = {}
                        for channel in channels
                            try
                                r = angular.fromJson(channel)
                                paths[r.path] ?= []
                                # # subscribe for changes if 'subscribe' is true or undefined
                                # subscribe = r.query.subscribe or not r.query.subscribe?
                                # # 'subscribe' is not part of the query
                                delete r.query.subscribe
                                # if subscribe then subscribePaths[r.path] = true
                                paths[r.path].push(r.query)
                            catch e
                                $log.error('channel is not a JSON string', channel)
                                return

                        @startConsumingAll(paths).then =>
                            angular.merge @trackedPaths, paths
                            # send stopConsuming messages after we get response
                            # for startConsuming messages, therefore no update
                            # will be lost
                            for path of @trackedPaths
                                if path not of paths
                                    # unsubscribe removed paths
                                    @stopConsuming(path)
                                    delete @trackedPaths[path]

                            # load all tracked path into cache
                            @loadAll()

                , @debounceTimeout

            messageHandler: (key, message) =>
                # ../type/id/event
                [type, id, event] = key.split('/')[-3..]
                # translate the event type
                if event is 'new' then event = EVENTS.NEW
                else event = EVENTS.UPDATE
                # update the object in the db
                indexedDBService.db[type].put(message).then =>
                    # emit the event
                    for path of @trackedPaths
                        if ///^#{path.replace(/\*/g, '(\\w+|\\d+)')}$///.test(key)
                            for query in @trackedPaths[path]
                                @emit path, query, event

            closeHandler: =>
                paths = angular.copy(@trackedPaths)
                @trackedPaths = {}
                @startConsumingAll(paths)

            loadAll: ->
                db = indexedDBService.db
                db.paths.toArray().then (paths) =>
                    for path, queries of @trackedPaths
                        for query in queries
                            @load(paths, path, query)

            load: (paths, path, query) ->
                $q (resolve, reject) =>
                    db = indexedDBService.db
                    tracking =
                        path: path
                        query: angular.toJson(query)

                    # in cache
                    t = dataUtilsService.type(path)
                    specification = SPECIFICATION[t]
                    for item in paths
                        inCache =
                            item.path is tracking.path and
                            item.query is tracking.query
                        elapsed = new Date() - new Date(item.lastActive)
                        active = isNaN(elapsed) or elapsed < 2000 or specification.static == true

                        if inCache and active
                            resolve()
                            return

                    restPath = dataUtilsService.restPath(path)
                    restService.get(restPath, query).then (data) =>
                        type = dataUtilsService.type(restPath)
                        data = dataUtilsService.unWrap(data, type)
                        db.transaction 'rw', db.paths, db[type], ->
                            if angular.isArray(data)
                                for i in data then db[type].put(i)
                            else db[type].put(data)
                            db.paths.put(tracking)
                        .then -> resolve()
                    , (error) -> reject(error)

                .then =>
                    @emit path, query, EVENTS.READY

            activatePaths: ->
                paths = angular.copy(@trackedPaths)
                db = indexedDBService.db
                db.transaction 'rw', db.paths, =>
                    now = (new Date()).toString()
                    for path, queries of paths
                        for query in queries
                            db.paths
                            .where('[path+query]').equals([path,angular.toJson(query)])
                            .modify('lastActive': now)

            on: (options..., listener) ->
                [path, query] = options
                channel =
                    path: path
                    query: query or {}
                @client.on angular.toJson(channel), listener

            off: (options..., listener) ->
                [path, query] = options
                channel =
                    path: path
                    query: query or {}
                @client.off angular.toJson(channel), listener

            emit: (options..., message) ->
                [path, query] = options
                channel =
                    path: path
                    query: query or {}
                @client.emit angular.toJson(channel), message, true

            startConsuming: (path) ->
                socketService.send
                    cmd: 'startConsuming'
                    path: path

            stopConsuming: (path) ->
                socketService.send
                    cmd: 'stopConsuming'
                    path: path

            startConsumingAll: (paths) ->
                if angular.isObject(paths)
                    socketPaths = Object.keys(paths)
                else if angular.isArray(paths)
                    socketPaths = paths[...]
                else throw new Error('Parameter paths is not an object or an array')

                # filter socket paths that are included in another paths
                pathsToRemove = []
                for p, i in socketPaths
                    r = ///^#{p.replace(/\*/g, '(\\w+|\\d+|\\*)')}$///
                    for q, j in socketPaths
                        if j != i and r.test(q) then pathsToRemove.push(q)
                for p in pathsToRemove
                    socketPaths.splice socketPaths.indexOf(p), 1

                promises = []
                for path in socketPaths
                    if path not of @trackedPaths
                        promises.push @startConsuming(path)

                return $q.all(promises)
