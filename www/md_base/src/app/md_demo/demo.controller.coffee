class Demo extends Controller
    constructor: ($scope, $timeout, dataService) ->
        @opened = dataService.open($scope)
        p = @opened.getBuilders(name: 'www')
        @builders = p.getArray()
        p.then =>
            @builders[0].loadBuildrequests()

    close: ->
        @builders.unsubscribe()

    close1: ->
        @builders[0].buildrequests.unsubscribe()

    close2: ->
