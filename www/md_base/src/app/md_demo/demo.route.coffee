class State extends Config
    constructor: (menuServiceProvider, $stateProvider) ->

        # Name of the state
        name = 'demo'

        menuServiceProvider.addItem
            name: name
            caption: 'Demo'
            icon: 'info'
            order: 30

        # Register new state
        $stateProvider.state
            controller: "#{name}Controller"
            controllerAs: name
            templateUrl: "views/#{name}.html"
            name: name
            url: "/#{name}"
