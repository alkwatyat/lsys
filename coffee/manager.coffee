DefaultSystem = new LSystem({
    size: {value:12.27}
    angle: {value:4187.5}
  }
  ,{}
  ,{
    size: {value:1}
  }
  ,"L : SS\nS : F->[F-Y[S(L]]\nY : [-|F-F+)Y]\n"
  ,12
  ,"click-and-drag-me!"
)

class InputHandler
  snapshot: null # lsystem params as they were was when joystick activated
  constructor: (@keystate, @joystick) ->
  update: (system) =>
    return if not @joystick.active
    if (@keystate.alt)
      system.params.size.value = Util.round(@snapshot.params.size.value + (@joystick.dy(system.sensitivities.size.value)), 2)
      system.params.size.growth = Util.round(@snapshot.params.size.growth + @joystick.dx(system.sensitivities.size.growth),6)
    else if (@keystate.meta or @keystate.ctrl)
      system.offsets.x = @snapshot.offsets.x + @joystick.dx()
      system.offsets.y = @snapshot.offsets.y + @joystick.dy()
    else
      system.params.angle.value = Util.round(system.params.angle.value + @joystick.dx(system.sensitivities.angle.value), 2)
      system.params.angle.growth = Util.round(system.params.angle.growth + @joystick.dy(system.sensitivities.angle.growth),9)


#yes this is an outrageous name for a .. system ... manager. buh.
class SystemManager
  joystick:null
  keystate: null
  inputHandler: null
  renderer:null
  currentSystem:null
  compiler: null
  constructor: (@canvas, @controls) ->
    @joystick = new Joystick(canvas)
    @keystate = new KeyState
    @inputHandler = new InputHandler(@keystate, @joystick)

    @joystick.onRelease = => @syncLocationQuiet()
    @joystick.onActivate = => @inputHandler.snapshot = @currentSystem.clone()

    @compiler = new SystemCompiler

    @renderer = new Renderer(canvas)
    @currentSystem = LSystem.fromUrl() or DefaultSystem
    @init()

  syncLocation: -> location.hash = @currentSystem.toUrl()
  syncLocationQuiet: -> location.quietSync = true; @syncLocation()

  # initialises a new system from the controls
  recalculate: ->
    Util.log('update from controls')
    newSystem = new LSystem(
      @paramControls.toJson(),
      @offsetControls.toJson(),
      @sensitivityControls.toJson(),
      $(@controls.rules).val(),
      parseInt($(@controls.iterations).val()),
      @currentSystem.name
    )
    Util.log('calling compile from updateContorls')
    @compiler.compile(newSystem).done( =>
      Util.log('i set new system')
      @currentSystem = newSystem
      @syncLocationQuiet()
    ).fail( =>
      Util.log('nope, no dice. Resetting back to original')
      @currentSystem = @compiler.lastCompiledSystem
    )

  exportToPng: ->
    [x,y] = [@canvas.width / 2 , @canvas.height / 2]

    b = @renderer.context.bounding
    c = $('<canvas></canvas>').attr({
      "width" : b.width()+30,
      "height": b.height()+30
    })[0]

    r = new Renderer(c)
    r.reset = (system) ->
      r.context.reset(system)
      r.context.state.x = (x-b.x1+15)
      r.context.state.y = (y-b.y1+15)

    @draw(r).then( -> Util.openDataUrl(c.toDataURL("image/png")) )

  init: ->
    @createBindings()
    @createControls()
    @syncAll()

  run: =>
    setTimeout(@run, 10)
    @inputHandler.update(@currentSystem)
    if @joystick.active and not @renderer.isDrawing
      @draw()
      @joystick.draw()
      @syncControls()


  draw: (renderer = @renderer) ->
    @compiler.compile(@currentSystem).then( (elems) =>
      renderer.render(elems, @currentSystem)
    )

  createControls: ->
    @paramControls = new Controls(Defaults.params(), ParamControl)
    @offsetControls = new OffsetControl(Defaults.offsets())
    @sensitivityControls = new Controls(Defaults.sensitivities(), SensitivityControl)

    @paramControls.create(@controls.params)
    @offsetControls.create(@controls.offsets)
    @sensitivityControls.create(@controls.sensitivities)

  syncAll: ->
    @syncControls()
    @syncRulesAndIterations()

  syncRulesAndIterations: ->
    $(@controls.iterations).val(@currentSystem.iterations)
    $(@controls.rules).val(@currentSystem.rules)

  syncControls: ->
    @paramControls.sync(@currentSystem.params)
    @offsetControls.sync(@currentSystem.offsets)
    @sensitivityControls.sync(@currentSystem.sensitivities)

  createBindings: ->
    setClassIf = (onOff, className) =>
      method = if (onOff) then 'add' else 'remove'
      $(@canvas)["#{method}Class"](className)

    updateCursorType = (ev) =>
      setClassIf(ev.ctrlKey or ev.metaKey, "moving")
      setClassIf(ev.altKey, "resizing")

    document.addEventListener("keydown", (ev) =>
      updateCursorType(ev)
      if ev.keyCode == Key.enter and ev.ctrlKey
        @recalculate()
        @syncLocation()
        return false
      if ev.keyCode == Key.enter and ev.shiftKey
        @exportToPng()
    )

    document.addEventListener("keyup", updateCursorType)
    document.addEventListener("mousedown", updateCursorType)

    window.onhashchange = =>
      if location.hash != ""
        newSystem = LSystem.fromUrl()
        console.log('seeing', newSystem.iterations)
        if (@compiler.lastCompiledSystem?.isIsomorphicTo(newSystem))
          @compiler.halt()
          console.log('isomorphic - merging')
          @currentSystem.merge(newSystem)
          @syncControls()
        else
          Util.log('initialising new system')
          @compiler.initialise(newSystem)
          @currentSystem = newSystem
          @syncAll()
        @draw() if not location.quietSync
        location.quietSync = false

#===========================================
