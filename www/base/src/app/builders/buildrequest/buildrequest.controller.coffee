class Buildrequest extends Controller
    constructor: ($scope, dataService, $stateParams, findBuilds, glBreadcrumbService, notFunctionsFilter) ->
        $scope.$watch "buildrequest.claimed", (n, o) ->
            if n  # if it is unclaimed, then claimed, we need to try again
                findBuilds $scope,
                    $scope.buildrequest.buildrequestid,
                    $stateParams.redirect_to_build

        opened = dataService.open($scope)
        opened.getBuildrequests($stateParams.buildrequest).then (buildrequests) ->
            buildrequest = buildrequests[0]
            $scope.buildrequest = notFunctionsFilter(buildrequest)
            opened.getBuilders(buildrequest.builderid).then (builders) ->
                $scope.builder = builder = builders[0]
                breadcrumb = [
                        caption: "buildrequests"
                        sref: "buildrequests"
                    ,
                        caption: builder.name
                        sref: "builder({builder:#{buildrequest.builderid}})"
                    ,
                        caption: buildrequest.id
                        sref: "buildrequest({buildrequest:#{buildrequest.id}})"
                ]

                glBreadcrumbService.setBreadcrumb(breadcrumb)

            opened.getBuildsets(buildrequest.buildsetid).then (buildsets) ->
                $scope.buildset = notFunctionsFilter(buildsets[0])
