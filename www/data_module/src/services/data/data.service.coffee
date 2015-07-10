class Data extends Provider
    constructor: ->
    # TODO caching
    cache: false

    ### @ngInject ###
    $get: ($log, $injector, $q, Collection, restService, dataUtilsService, tabexService, indexedDBService, SPECIFICATION) ->
        return new class DataService
            self = null
            constructor: ->
                self = @
                # generate loadXXX functions for root endpoints
                endpoints = Object.keys(SPECIFICATION).filter (e) -> SPECIFICATION[e].root
                @constructor.generateEndpoints(endpoints)

            # the arguments are in this order: endpoint, id, child, id of child, query
            get: (args...) ->

                query = @processArguments(args)

                restPath = dataUtilsService.restPath(args)
                # up to date collection, this will be returned
                promise = new Collection(restPath, query)

                return promise

            processArguments: (args) ->
                # keep defined arguments only
                args.filter (e) -> e?
                # get the query parameters
                [..., last] = args
                if angular.isObject(last)
                    query = args.pop()
                return query

            # control: (method, params) ->
            #     @jsonrpc ?= 1
            #     restService.post
            #         id: @jsonrpc++
            #         jsonrpc: '2.0'
            #         method: method
            #         params: params

            # generate functions for root endpoints
            @generateEndpoints: (endpoints) ->
                endpoints.forEach (e) =>
                    # capitalize endpoint names
                    E = dataUtilsService.capitalize(e)
                    @::["get#{E}"] = (args...) =>
                        self.get(e, args...)


            # opens a new accessor
            open: (scope) ->
                return new class DataAccessor
                    collections = []
                    constructor: ->
                        # generate loadXXX functions for root endpoints
                        endpoints = Object.keys(SPECIFICATION).filter (e) -> SPECIFICATION[e].root
                        @constructor.generateEndpoints(endpoints)

                        if scope? then @closeOnDestroy(scope)

                    # calls unsubscribe on each root classes
                    close: ->
                        collections.forEach (c) -> c.unsubscribe?()

                    # closes the group when the scope is destroyed
                    closeOnDestroy: (scope) ->
                        if not angular.isFunction(scope.$on)
                            throw new Error("Parameter 'scope' doesn't have an $on function")
                        scope.$on '$destroy', => @close()

                    # generate functions for root endpoints
                    @generateEndpoints: (endpoints) ->
                        endpoints.forEach (e) =>
                            E = dataUtilsService.capitalize(e)
                            @::["get#{E}"] = (args...) =>
                                p = self["get#{E}"](args...)
                                collections.push(p.getArray())
                                return p
