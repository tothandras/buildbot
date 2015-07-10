class Collection extends Factory
    constructor: ($q, $injector, $log, dataUtilsService, tabexService, indexedDBService, SPECIFICATION) ->
        return class CollectionInstance extends Array
            Wrapper = null
            constructor: (restPath, query = {}) ->
                @getRestPath = -> restPath
                @getQuery = -> query
                @getSocketPath = -> dataUtilsService.socketPath(restPath)
                @getType = -> dataUtilsService.type(restPath)
                @getEndpoint = -> dataUtilsService.endpointPath(restPath)
                @getSpecification = -> SPECIFICATION[@getType()]

                ready = $q.defer()
                @getReadyDeferred = -> ready
                @getReadyPromise = -> ready.promise

                className = dataUtilsService.className(restPath)
                Wrapper = $injector.get('Wrapper')

                return @subscribe()

            listener: (event) =>
                indexedDBService.get(@getRestPath(), @getQuery()).then (data) =>
                    switch event
                        when tabexService.EVENTS.READY then @readyHandler(data)
                        when tabexService.EVENTS.UPDATE then @updateHandler(data)
                        when tabexService.EVENTS.NEW then @newHandler(data)
                        else $log.error('Unhandled tabex event', event)

            readyHandler: (data) ->
                if @length == 0 then @from(data)
                @getReadyDeferred()?.resolve(@)

            # add new elements and remove old ones
            newHandler: (data) ->
                id = @getSpecification().id
                ids =
                    new: data.map (e) -> e[id]
                    old: @map (e) -> e[id]

                # add new
                data.forEach (e) => if e[id] not in ids.old then @add(e)

                # delete old
                @forEach (e) => if e[id] not in ids.new then @delete(e)

            updateHandler: (data) ->
                @newHandler(data)

                id = @getSpecification().id
                for e in data
                    @forEach (i) -> if e[id] == i[id] then i.update(e)

            subscribe: ->
                tabexService.on @getSocketPath(), @getQuery(), @listener
                promise = @getReadyPromise()
                promise.getArray = => return this
                return promise

            unsubscribe: ->
                @forEach (e) -> e?.unsubscribe?()
                tabexService.off @getSocketPath(), @getQuery(), @listener

            from: (data) ->
                if not angular.isArray(data) then @add(data)
                # add items one by one
                else @add(i) for i in data

            add: (element) ->
                instance = new Wrapper(element, @getEndpoint())
                @push(instance)

            clear: ->
                @pop() while @length > 0

            delete: (element) ->
                index = @indexOf(element)
                if index > -1 then @splice(index, 1)

            # # TODO untested
            # loadMore: (limit) ->
            #     if q.limit?
            #         q = angular.copy(@getQuery() or {})
            #         q.offset = @length
            #         q.limit = limit
            #         # TODO @subscribe
