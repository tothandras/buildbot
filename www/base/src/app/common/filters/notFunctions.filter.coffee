class NotFunctions extends Filter('common')
    constructor: ->
        return (items) ->
            r = {}
            for own k, v of items
                if not angular.isFunction(v) then r[k] = v
            return r
