class Buildsummary extends Directive('common')
    constructor: (RecursionHelper) ->
        return {
            replace: true
            restrict: 'E'
            scope: {buildid: '=', condensed: '=', prefix: "@"}
            templateUrl: 'views/buildsummary.html'
            compile: RecursionHelper.compile
            controller: '_buildsummaryController'
        }

class _buildsummary extends Controller('common')
    constructor: ($scope, dataService, resultsService, $urlMatcherFactory, $location) ->
        baseurl = $location.absUrl().split("#")[0]
        buildrequestURLMatcher = $urlMatcherFactory.compile(
            "#{baseurl}#buildrequests/{buildrequestid:[0-9]+}")
        buildURLMatcher = $urlMatcherFactory.compile(
            "#{baseurl}#builders/{builderid:[0-9]+}/builds/{buildid:[0-9]+}")

        NONE = 0
        ONLY_NOT_SUCCESS = 1
        EVERYTHING = 2
        details = EVERYTHING
        if $scope.condensed
            details = NONE

        $scope.$watch (-> moment().unix()), ->
            $scope.now = moment().unix()

        # make resultsService utilities available in the template
        _.mixin($scope, resultsService)

        $scope.toggleDetails = ->
            details = (details + 1 ) % 3

        $scope.isStepDisplayed = (step) ->
            if details == EVERYTHING
                return !step.hidden
            else if details == ONLY_NOT_SUCCESS
                return not step.results? or step.results != 0
            else if details == NONE
                return false

        $scope.getBuildRequestIDFromURL = (url) ->
            return parseInt(buildrequestURLMatcher.exec(url).buildrequestid, 10)

        $scope.isBuildRequestURL = (url) ->
            return buildrequestURLMatcher.exec(url) != null

        $scope.isBuildURL = (url) ->
            return buildURLMatcher.exec(url) != null


        opened = dataService.open($scope)
        $scope.$watch 'buildid', (buildid) ->
            $scope.buldid = buildid

            opened.getBuilds($scope.buildid).then (builds) ->
                $scope.build = build = builds[0]
                opened.getBuilders(build.builderid).then (builders) ->
                    $scope.builder = builder = builders[0]

                build.getSteps().then (steps) ->
                    $scope.steps = steps
                    steps.forEach (step) ->
                        $scope.$watch (-> step.complete), ->
                            step.fulldisplay = step.complete == 0 || step.results > 0
                            if step.complete
                                step.duration = step.complete_at - step.started_at
                        step.loadLogs()
