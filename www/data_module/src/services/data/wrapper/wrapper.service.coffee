class Wrapper extends Factory
    constructor: ($log, dataService, dataUtilsService, tabexService, SPECIFICATION) ->
        return class WrapperInstance
            endpoint = null
            constructor: (object, e) ->
                endpoint = e
                if not angular.isString(endpoint)
                    throw new TypeError("Parameter 'endpoint' must be a string, not #{typeof endpoint}")

                # add object fields to the instance
                @update(object)

                # generate loadXXX functions
                endpoints = Object.keys(SPECIFICATION)
                @constructor.generateFunctions(endpoints)

            update: (o) ->
                angular.merge(@, o)

            get: (args...) ->
                dataService.get(endpoint, @getId(), args...)

            # generate endpoint functions for the class
            @generateFunctions: (endpoints) ->
                endpoints.forEach (e) =>
                    # capitalize endpoint names
                    E = dataUtilsService.capitalize(e)
                    # adds loadXXX functions to the prototype
                    @::["load#{E}"] = (args...) ->
                        query = []
                        query["#{@classId()}"] = @getId()
                        idx = args.length - 1
                        if angular.isObject(args[idx]) then angular.extend args[idx], query
                        else args.push(query)
                        p = @get(e, args...)
                        @[e] = p.getArray()
                        return p

            getId: ->
                @[@classId()]

            classId: ->
                SPECIFICATION[dataUtilsService.type(endpoint)].id

            unsubscribe: ->
                e?.unsubscribe?() for _, e of this
