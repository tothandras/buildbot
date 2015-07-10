class DataUtils extends Service
    constructor: ->

    # capitalize first word
    capitalize: (w) ->
        w[0].toUpperCase() + w[1..-1].toLowerCase()

    # returns the type of the endpoint
    type: (arg) ->
        # if the argument count is even, the last argument is an id
        a = @copyOrSplit(arg)
        a = a.filter (e) -> e isnt '*'
        # is it even, then throw the id
        if a.length % 2 is 0 then a.pop()
        a.pop()

    # singularize the type name
    singularType: (arg) ->
        @type(arg).replace(/s$/, '')

    # capitalized type name
    className: (arg) ->
        @capitalize(@singularType(arg))

    socketPath: (arg) ->
        a = @copyOrSplit(arg)
        # if the argument count is even, the last argument is an id
        stars = ['*']
        # is it odd?
        if a.length % 2 is 1 then stars.push('*')
        a.concat(stars).join('/')

    restPath: (arg) ->
        a = @copyOrSplit(arg)
        a = a.filter (e) -> e isnt '*'
        a.join('/')

    endpointPath: (arg) ->
        # if the argument count is even, the last argument is an id
        a = @copyOrSplit(arg)
        # is it even?
        if a.length % 2 is 0 then a.pop()
        a.join('/')

    id: (arg) ->
        a = @copyOrSplit(arg)
        # if the argument count is even, the last argument is an id
        if a.length % 2 is 0
            stringId = a.pop()
            return @numberOrStringId(stringId)
        return null

    numberOrStringId: (stringId) ->
        numberId = parseInt stringId, 10
        if !isNaN(numberId) then numberId
        else stringId

    copyOrSplit: (arrayOrString) ->
        if angular.isArray(arrayOrString)
            # return a copy
            arrayOrString.slice()
        else if angular.isString(arrayOrString)
            # split the string to get an array
            arrayOrString.split('/')
        else
            throw new TypeError("Parameter 'arrayOrString' must be a array or a string, not #{typeof arrayOrString}")

    unWrap: (data, restPath) ->
        type = @type(restPath)
        data[type]
