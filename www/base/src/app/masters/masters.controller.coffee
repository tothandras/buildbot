class Masters extends Controller
    constructor: ($scope, dataService, notFunctionsFilter) ->
        dataService.getMasters().then (masters) ->
            $scope.masters = masters.map (master) -> notFunctionsFilter(master)
