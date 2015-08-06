describe 'Wrapper', ->
    beforeEach module 'bbData'
    beforeEach module ($provide) ->
        $provide.constant 'SPECIFICATION',
            asd:
                id: 'aid'
                identifier: 'aidentifier'

    Wrapper = $q = $rootScope = tabexService = indexedDBService = data = i = undefined
    injected = ($injector) ->
        $q = $injector.get('$q')
        $rootScope = $injector.get('$rootScope')
        Wrapper = $injector.get('Wrapper')
        tabexService = $injector.get('tabexService')
        indexedDBService = $injector.get('indexedDBService')

        data =
            aid: 12
            aidentifier: 'n12'
        i = new Wrapper(data, 'asd')

    beforeEach(inject(injected))

    it 'should be defined', ->
        expect(Wrapper).toBeDefined()
        expect(i).toBeDefined()

    it 'should add the data to the object passed in to the constructor', ->
        for k, v in data
            expect(i[k]).toEqual(v)

    it 'should generate functions for every type in the specification', ->
        expect(i.loadAsd).toBeDefined()
        expect(angular.isFunction(i.loadAsd)).toBeTruthy()

    # TODO
    describe 'get(args)', ->

        it '', ->

    describe 'getId()', ->

        it 'should return the id value', ->
            expect(i.getId()).toEqual(data.aid)

    describe 'getIdentifier()', ->

        it 'should return the identifier value', ->
            expect(i.getIdentifier()).toEqual(data.aidentifier)

    describe 'classId()', ->

        it 'should return the id name', ->
            expect(i.classId()).toEqual('aid')

    describe 'classIdentifier()', ->

        it 'should return the identifier name', ->
            expect(i.classIdentifier()).toEqual('aidentifier')

    describe 'unsubscribe()', ->

        it 'call unsubscribe on each object', ->
            i.obj = unsubscribe: jasmine.createSpy('unsubscribe')
            expect(i.obj.unsubscribe).not.toHaveBeenCalled()
            i.unsubscribe()
            expect(i.obj.unsubscribe).toHaveBeenCalled()
