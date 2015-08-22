class Build extends Controller
    constructor: ($rootScope, $scope, $location, $stateParams, $state,
                  dataService, dataUtilsService, recentStorage, notFunctionsFilter,
                  glBreadcrumbService, glTopbarContextualActionsService) ->

        builderid = _.parseInt($stateParams.builder)
        buildnumber = _.parseInt($stateParams.build)

        $scope.last_build = true
        $scope.is_stopping = false

        $scope.$watch 'build.complete', (n, o) ->
            if n == true
                glTopbarContextualActionsService.setContextualActions []

            else if n == false and not $scope.is_stopping
                glTopbarContextualActionsService.setContextualActions [
                        caption: "Stop"
                        extra_class: "btn-danger"
                        action: ->
                            $scope.is_stopping = true
                            dataService.control("builds/#{$scope.build.buildid}", 'stop').then (->), (why) ->
                                $scope.is_stopping = false
                                $scope.error = "Cannot stop: " + why.data.error.message
                                glTopbarContextualActionsService.setContextualActions []
                ]

        $scope.$watch 'is_stopping', (n, o) ->
            if n == true
                glTopbarContextualActionsService.setContextualActions [
                        caption: "Stopping..."
                        icon: "spinner fa-spin"
                ]

        opened = dataService.open($scope)
        opened.getBuilders(builderid).then (builders) ->
            $scope.builder = builder = builders[0]
            builder.getBuilds(number: buildnumber).then (builds) ->
                $scope.build = build = builds[0]
                if not build.number? and buildnumber > 1
                    $state.go('build', builder:builderid, build:buildnumber - 1)
                breadcrumb = [
                        caption: "Builders"
                        sref: "builders"
                    ,
                        caption: builder.name
                        sref: "builder({builder:#{builderid}})"
                    ,
                        caption: build.number
                        sref: "build({build:#{buildnumber}})"
                ]

                glBreadcrumbService.setBreadcrumb(breadcrumb)

                unwatch = $scope.$watch 'nextbuild.number', (n, o) ->
                    if n?
                        $scope.last_build = false
                        unwatch()

                recentStorage.addBuild
                    link: "#/builders/#{$scope.builder.builderid}/builds/#{$scope.build.number}"
                    caption: "#{$scope.builder.name} / #{$scope.build.number}"

                opened.getBuilds(build.buildid).then (builds) ->
                    build = builds[0]
                    $scope.properties = build.getProperties().getArray()
                    $scope.changes = build.getChanges().getArray()
                    $scope.$watch 'changes', (changes) ->
                        if changes?
                            responsibles = {}
                            for change in changes
                                change.author_email = dataUtilsService.emailInString(change.author)
                                responsibles[change.author] = change.author_email
                            $scope.responsibles = responsibles
                    , true

                opened.getBuildslaves(build.buildslaveid).then (buildslaves) ->
                    $scope.buildslave = notFunctionsFilter(buildslaves[0])

                opened.getBuildrequests(build.buildrequestid).then (buildrequests) ->
                    $scope.buildrequest = buildrequest = buildrequests[0]
                    opened.getBuildsets(buildrequest.buildsetid).then (buildsets) ->
                        $scope.buildset = buildsets[0]

            builder.getBuilds(number: buildnumber + 1).then (builds) ->
                $scope.nextbuild = builds[0]
