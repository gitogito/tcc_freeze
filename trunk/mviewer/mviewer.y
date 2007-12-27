class TcParser

options no_result_var

prechigh
  right TK_POW
  right NEG
  left '*' '/'
  left '+' '-'
preclow

rule

input:
    world commands

  | var_assigns world commands

var_assigns:
    var_assign

  | var_assigns var_assign

var_assign:
    TK_WORD '=' expr
    { @vars[val[0]] = val[2] }

world:
    TK_DASH TK_WORLD point ',' vector ',' expr ',' expr ',' expr
    {
      obj = Box.new(*val.values_at(2, 4))
      obj.type = :WORLD
      @obj_ary << obj
    }

  | TK_DASH TK_WORLD point ',' point ',' expr ',' expr ',' expr
    {
      val[4][0] -= val[2][0]
      val[4][1] -= val[2][1]
      val[4][2] -= val[2][2]
      obj = Box.new(*val.values_at(2, 4))
      obj.type = :WORLD
      @obj_ary << obj
    }

commands:
    command

  | commands command

command:
    TK_DASH TK_ACTIVE obj
    {
      val[2].type = :ACTIVE
      @obj_ary << val[2]
    }

  | TK_DASH TK_NOACTIVE obj
    {
      val[2].type = :NOACTIVE
      @obj_ary << val[2]
    }

  | TK_DASH TK_FIX expr obj
    {
      val[3].type = :FIX
      @obj_ary << val[3]
    }

  | TK_DASH TK_FIX TK_HEAT expr obj
    {
      val[4].type = :FIXHEAT
      @obj_ary << val[4]
    }

  | TK_DASH TK_HEAT TK_FIX expr obj
    {
      val[4].type = :FIXHEAT
      @obj_ary << val[4]
    }

  | TK_DASH TK_HEAT expr obj
    {
      val[3].type = :HEAT
      @obj_ary << val[3]
    }

  | TK_DASH TK_LAMBDA expr obj
    {
      val[3].type = :LAMBDA
      @obj_ary << val[3]
    }

point:
    '(' expr ',' expr ',' expr ')'
    {
      val.values_at(1, 3, 5)
    }

point2d:
    '(' expr ',' expr ')'
    {
      val.values_at(1, 3)
    }

point2d_ary:
    point2d
    { [ val[0] ] }

  | point2d_ary ',' point2d
    { val[0] + [ val[2] ] }

vector:
    '<' expr ',' expr ',' expr '>'
    { val.values_at(1, 3, 5) }

vector2d:
    '<' expr ',' expr '>'
    { val.values_at(1, 3) }

vector2d_ary:
    vector2d
    { [ val[0] ] }

  | vector2d_ary ',' vector2d
    { val[0] + [ val[2] ] }

expr:
    expr '+' expr
    { val[0] + val[2] }

  | expr '-' expr
    { val[0] - val[2] }

  | expr '*' expr
    { val[0] * val[2] }

  | expr '/' expr
    { val[0] / val[2] }

  | expr TK_POW expr
    { val[0] ** val[2] }

  | '(' expr ')'
    { val[1] }

  | '-' expr =NEG
    { -val[1] }

  | TK_NUMBER

  | TK_WORD
    { @vars[val[0]] }

  | var_assign

obj:
    TK_BOX point ',' vector
    { Box.new(*val.values_at(1, 3)) }

  | TK_BOX point ',' point
    {
      val[3][0] -= val[1][0]
      val[3][1] -= val[1][1]
      val[3][2] -= val[1][2]
      Box.new(*val.values_at(1, 3))
    }

  | TK_RECT TK_SYMBOL ',' point ',' vector2d
    { Rect.new(*val.values_at(1, 3, 5)) }

  | TK_RECT TK_SYMBOL ',' point ',' point2d
    {
      vec2d = point2d_sub_point(val[1], val[5], val[3])
      Rect.new(val[1], val[3], vec2d)
    }

  | TK_TRIANGLE TK_SYMBOL ',' point ',' vector2d ',' vector2d
    {
      Triangle.new(*val.values_at(1, 3, 5, 7))
    }

  | TK_TRIANGLE TK_SYMBOL ',' point ',' point2d ',' point2d
    {
      vec2d1 = point2d_sub_point(val[1], val[5], val[3])
      vec2d2 = point2d_sub_point(val[1], val[7], val[3])
      Triangle.new(val[1], val[3], vec2d1, vec2d2)
    }

  | TK_CIRCLE TK_SYMBOL ',' point ',' expr
    { Circle.new(*val.values_at(1, 3, 5)) }

  | TK_ELLIPSE TK_SYMBOL ',' point ',' expr ',' expr
    { Ellipse.new(*val.values_at(1, 3, 5, 7)) }

  | TK_POLYGON TK_SYMBOL ',' point ',' vector2d_ary
    { Polygon.new(*val.values_at(1, 3, 5)) }

  | TK_POLYGON TK_SYMBOL ',' point ',' point2d_ary
    {
      ary = []
      val[5].each do |pnt|
        vec2d = point2d_sub_point(val[1], pnt, val[3])
        ary << vec2d
      end
      Polygon.new(val[1], val[3], ary)
    }

  | TK_LINE TK_SYMBOL ',' point ',' vector2d_ary
    { Polygon.new(*val.values_at(1, 3, 5)) }

  | TK_LINE TK_SYMBOL ',' point ',' point2d_ary
    {
      ary = []
      val[5].each do |pnt|
        vec2d = point2d_sub_point(val[1], pnt, val[3])
        ary << vec2d
      end
      Polygon.new(val[1], val[3], ary)
    }

  | TK_SWEEP TK_SYMBOL ',' expr ',' obj
    { Sweep.new(*val.values_at(1, 3, 5)) }

  | TK_EDGE obj
    { val[1] }

  | '[' objs ']'
    {
      val[1]
    }

objs:
    obj
    { Objs.new(val[0]) }

  | objs obj
    {
      val[0] << val[1]
      val[0]
    }


---- header

require 'vtk'
require 'vtk/util'

class Obj
  attr_accessor :type
  attr_reader :actor
end

class Rect < Obj
  def initialize(axis, point, vector2d)
    points = Vtk::Points.new
    points.SetNumberOfPoints(4)
    case axis
    when :X
      points.InsertPoint(0, point[0], point[1]              , point[2]              )
      points.InsertPoint(1, point[0], point[1] + vector2d[0], point[2]              )
      points.InsertPoint(2, point[0], point[1] + vector2d[0], point[2] + vector2d[1])
      points.InsertPoint(3, point[0], point[1]              , point[2] + vector2d[1])
    when :Y
      points.InsertPoint(0, point[0]              , point[1], point[2]              )
      points.InsertPoint(1, point[0] + vector2d[0], point[1], point[2]              )
      points.InsertPoint(2, point[0] + vector2d[0], point[1], point[2] + vector2d[1])
      points.InsertPoint(3, point[0]              , point[1], point[2] + vector2d[1])
    when :Z
      points.InsertPoint(0, point[0]              , point[1]              , point[2])
      points.InsertPoint(1, point[0] + vector2d[0], point[1]              , point[2])
      points.InsertPoint(2, point[0] + vector2d[0], point[1] + vector2d[1], point[2])
      points.InsertPoint(3, point[0]              , point[1] + vector2d[1], point[2])
    else
      raise "bug: unknown axis #{axis}"
    end
    polygon = Vtk::Quad.new
    polygon.GetPointIds.SetId(0, 0)
    polygon.GetPointIds.SetId(1, 1)
    polygon.GetPointIds.SetId(2, 2)
    polygon.GetPointIds.SetId(3, 3)
    grid = Vtk::UnstructuredGrid.new
    grid.Allocate(1, 1)
    grid.InsertNextCell(polygon.GetCellType, polygon.GetPointIds)
    grid.SetPoints(points)
    mapper = Vtk::DataSetMapper.new
    mapper.SetInput(grid)
    @actor = Vtk::Actor.new
    @actor.SetMapper(mapper)
  end
end

class Triangle < Obj
  def initialize(axis, point, vector2d_a, vector2d_b)
    @actor = Polygon.new(axis, point, [vector2d_a, vector2d_b]).actor
  end
end

class Ellipse < Obj
  def initialize(axis, point, ru, rv)
    cylinder = Vtk::CylinderSource.new
    cylinder.SetResolution(32)
    cylinder.SetHeight(0.0)
    mapper = Vtk::PolyDataMapper.new
    mapper.SetInputConnection(cylinder.GetOutputPort)
    @actor = Vtk::Actor.new
    @actor.SetMapper(mapper)
    case axis
    when :X
      @actor.SetScale(ru, 1.0, rv)
      @actor.RotateZ(90)
      @actor.SetPosition(*point)
    when :Y
      @actor.SetScale(ru, 1.0, rv)
      @actor.SetPosition(*point)
    when :Z
      @actor.SetScale(ru, 1.0, rv)
      @actor.RotateX(90)
      @actor.SetPosition(*point)
    end
  end
end

class Circle < Obj
  def initialize(axis, point, r)
    @actor = Ellipse.new(axis, point, r, r).actor
  end
end

class Box < Obj
  def initialize(point, vector)
    cube = Vtk::CubeSource.new
    cube.SetBounds(
      point[0], point[0] + vector[0],
      point[1], point[1] + vector[1],
      point[2], point[2] + vector[2]
      )
    cubeMapper = Vtk::PolyDataMapper.new
    cubeMapper.SetInputConnection(cube.GetOutputPort)
    @actor = Vtk::Actor.new
    @actor.SetMapper(cubeMapper)
  end
end

class Sweep < Obj
  def initialize(axis, val, obj)
    STDERR.puts "implementation of Sweep is unfinished"
    @actor = obj.actor
  end
end

class Polygon < Obj
  def initialize(axis, point, vector2d_ary)
    points = Vtk::Points.new
    points.SetNumberOfPoints(1 + vector2d_ary.size)
    points.InsertPoint(0, *point)
    vector2d_ary.each_with_index do |v2d, i|
      case axis
      when :X
        points.InsertPoint(1 + i, point[0]         , point[1] + v2d[0], point[2] + v2d[1])
      when :Y
        points.InsertPoint(1 + i, point[0] + v2d[0], point[1]         , point[2] + v2d[1])
      when :Z
        points.InsertPoint(1 + i, point[0] + v2d[0], point[1] + v2d[1], point[2]         )
      else
        raise "bug: unknown axis #{axis}"
      end
    end
    polygon = Vtk::Polygon.new
    polygon.GetPointIds.SetNumberOfIds(points.GetNumberOfPoints)
    points.GetNumberOfPoints.times do |i|
      polygon.GetPointIds.SetId(i, i)
    end
    grid = Vtk::UnstructuredGrid.new
    grid.Allocate(1, 1)
    grid.InsertNextCell(polygon.GetCellType, polygon.GetPointIds)
    grid.SetPoints(points)
    mapper = Vtk::DataSetMapper.new
    mapper.SetInput(grid)
    @actor = Vtk::Actor.new
    @actor.SetMapper(mapper)
  end
end

class Objs
  def initialize(obj)
    @objs = [obj]
  end

  def type=(t)
    @objs.each do |obj|
      obj.type = t
    end
  end

  def <<(obj)
    @objs << obj
  end

  def each
    @objs.each do |obj|
      yield obj
    end
  end
end


---- inner

NumberPat = '(?: [-+]?\d*\.\d+(?:[eE][-+]?\d+)? | ' +
  '[-+]?\d+\.?(?:[eE][-+]?\d+)? )'

attr_reader :obj_ary

class ObjAry
  def initialize
    @ary = []
  end

  def <<(obj)
    if obj.kind_of?(Objs)
      obj.each do |aobj|
        @ary << aobj
      end
    else
      @ary << obj
    end
  end

  def each
    @ary.each do |obj|
      yield obj
    end
  end
end

def parse(str)
  @yydebug = false

  @state = nil
  @vars = {}

  @obj_ary = ObjAry.new

  str = str.strip
  @q = []
  until str.empty?
    case str
    when /\A\s+/
      str = $'
    when /\A#.*/
      str = $'
    when /\A---+/
      @q.push [:TK_DASH, $&]
      str = $'
    when /\Aactive\b/
      @q.push [:TK_ACTIVE, $&]
      str = $'
    when /\Abox\b/
      @q.push [:TK_BOX, $&]
      str = $'
    when /\Acircle\b/
      @q.push [:TK_CIRCLE, $&]
      str = $'
    when /\Aedge\b/
      @q.push [:TK_EDGE, $&]
      str = $'
    when /\Aellipse\b/
      @q.push [:TK_ELLIPSE, $&]
      str = $'
    when /\Afix\b/
      @q.push [:TK_FIX, $&]
      str = $'
    when /\Aheat\b/
      @q.push [:TK_HEAT, $&]
      str = $'
    when /\Alambda\b/
      @q.push [:TK_LAMBDA, $&]
      str = $'
    when /\Aline\b/
      @q.push [:TK_LINE, $&]
      str = $'
    when /\Anoactive\b/
      @q.push [:TK_NOACTIVE, $&]
      str = $'
    when /\Apolygon\b/
      @q.push [:TK_POLYGON, $&]
      str = $'
    when /\Arect\b/
      @q.push [:TK_RECT, $&]
      str = $'
    when /\Asweep\b/
      @q.push [:TK_SWEEP, $&]
      str = $'
    when /\Atriangle\b/
      @q.push [:TK_TRIANGLE, $&]
      str = $'
    when /\Aworld\b/
      @q.push [:TK_WORLD, $&]
      str = $'
    when /\A#{NumberPat}/ox
      @q.push [:TK_NUMBER, $&.to_f]
      str = $'
    when /\A[a-zA-Z]\w*/
      @q.push [:TK_WORD, $&]
      str = $'
    when /\A:[a-zA-Z]\w*/
      @q.push [:TK_SYMBOL, eval($&)]
      str = $'
    when /\A\*\*/
      @q.push [:TK_POW, $&]
      str = $'
    else
      c = str[0, 1]
      @q.push [c, c]
      str = str[1 .. -1]
    end
  end
  @q.push [false, '$']   # is optional from Racc 1.3.7
  do_parse
end

def next_token
  @q.shift
end

def on_error(error_token_id, error_value, value_stack)
  STDERR.puts "parse error: '#{error_value}'"
  exit 1
end

def point2d_sub_point(axis, point2d, point)
  pnt2d = point2d.dup
  case axis
  when :X
    pnt2d[0] -= point[1]
    pnt2d[1] -= point[2]
  when :Y
    pnt2d[0] -= point[0]
    pnt2d[1] -= point[2]
  when :Z
    pnt2d[0] -= point[0]
    pnt2d[1] -= point[1]
  else
    raise "unknown axis '#{axis}'"
  end
  pnt2d
end


---- footer

def next_state(state)
  st_ary = [ :ALL, :ACTIVE, :NOACTIVE, :FIX, :FIXHEAT, :HEAT, :LAMBDA ]
  index = st_ary.index(state)
  if index.nil?
    raise "unknown state #{state}"
  end
  st_ary[(index + 1) % st_ary.size]
end

parser = TcParser.new
parser.parse(ARGF.read)

parser.obj_ary.each do |obj|
  obj.actor.GetProperty.SetOpacity(0.3)
  case obj.type
  when :WORLD
    obj.actor.GetProperty.SetColor(0.3, 0.3, 0.3)
    obj.actor.GetProperty.SetRepresentationToWireframe
  when :ACTIVE
    obj.actor.GetProperty.SetColor(1, 1, 1)
  when :NOACTIVE
    obj.actor.GetProperty.SetColor(0.1, 0.1, 0.1)
  when :FIX
    obj.actor.GetProperty.SetColor(0, 0, 1)
  when :FIXHEAT
    obj.actor.GetProperty.SetColor(1, 0, 0)
  when :HEAT
    obj.actor.GetProperty.SetColor(1, 0, 0)
  when :LAMBDA
    obj.actor.GetProperty.SetColor(0.5, 0.5, 0.5)
  else
    raise "unknown type #{obj.type}"
  end
end

ren = Vtk::Renderer.new
ren.SetBackground(Vtk::Colors::Slate_grey)
parser.obj_ary.each do |obj|
  ren.AddActor(obj.actor)
end

renWin = Vtk::RenderWindow.new
renWin.AddRenderer(ren)
renWin.SetSize(500, 500)

iren = Vtk::RenderWindowInteractor.new
iren.SetRenderWindow(renWin)

state = :ALL

keypress = Proc.new do |obj, event|
  key = obj.GetKeySym
  case key
  when "a"
    state = next_state(state)
    STDERR.puts state
  end

  case state
  when :ALL
    parser.obj_ary.each do |obj|
      obj.actor.VisibilityOn
    end
  else
    parser.obj_ary.each do |obj|
      if obj.type == :WORLD or obj.type == state
        obj.actor.VisibilityOn
      else
        obj.actor.VisibilityOff
      end
    end
  end
  iren.Render
end
iren.AddObserver("KeyPressEvent", keypress)

style = Vtk::InteractorStyleTrackballCamera.new
iren.SetInteractorStyle(style)

iren.Initialize
iren.Start
