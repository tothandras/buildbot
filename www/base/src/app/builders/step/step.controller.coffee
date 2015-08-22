class Step extends Controller
    constructor: ($log, $scope, $location, dataService, dataUtilsService, $stateParams, glBreadcrumbService, notFunctionsFilter) ->
        opened = dataService.open($scope)
        builderid = dataUtilsService.numberOrString($stateParams.builder)
        buildnumber = dataUtilsService.numberOrString($stateParams.build)
        stepnumber = dataUtilsService.numberOrString($stateParams.step)
        opened.getBuilders(builderid).then (builders) ->
            $scope.builder = builder = builders[0]
            builder.getBuilds(buildnumber).then (builds) ->
                $scope.build = build = builds[0]
                build.getSteps(stepnumber).then (steps) ->
                    step = steps[0]
                    step.loadLogs()
                    $scope.step = notFunctionsFilter(step)
