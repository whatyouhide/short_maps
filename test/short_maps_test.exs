defmodule ShortMapsTest do
  use ExUnit.Case, async: true
  doctest ShortMaps, import: true

  import ShortMaps

  test "uses the bindings from the current environment" do
    foo = 1
    assert ~m(foo)a == %{foo: 1}
    assert ~m(foo) == %{"foo" => 1}
  end

  test "can be used in pattern matches, where it binds variables" do
    assert ~m(foo)a = %{foo: "bar"}
    assert foo == "bar"
  end

  test "supports the ^pin syntax in pattern matches to match on a variable's value" do
    foo = "bar"

    assert ~m(^foo)a = %{foo: "bar"}

    message = "no match of right hand side value: %{foo: \"baaz\"}"
    assert_raise MatchError, message, fn ->
      foo = "bar"
      ~m(^foo)a = %{foo: "baaz"}
    end
  end

  test "can be used in function heads for anonymoys functions" do
    fun = fn
      ~m(foo)a ->
        {:matched, foo}
      _ ->
        :no_match
    end

    assert fun.(%{foo: "bar"}) == {:matched, "bar"}
    assert fun.(%{baz: "bong"}) == :no_match
  end

  test "can be used in function heads for functions in modules" do
    defmodule FunctionHead do
      def test(~m(foo)a), do: {:matched, foo}
      def test(_other), do: :no_match
    end

    assert FunctionHead.test(%{foo: "bar"}) == {:matched, "bar"}
    assert FunctionHead.test(%{baz: "bong"}) == :no_match
  after
    :code.delete(FunctionHead)
    :code.purge(FunctionHead)
  end

  test "supports atom keys with the 'a' modifier" do
    # For matching
    assert ~m(foo bar)a = %{foo: "hello", bar: "world"}
    assert foo == "hello"
    assert bar == "world"

    # For using the variables from the current environment
    assert ~m(foo bar)a == %{foo: "hello", bar: "world"}
  end

  test "supports string keys with the 's' modifier" do
    # For matching
    assert ~m(foo bar)s = %{"foo" => "hello", "bar" => "world"}
    assert foo == "hello"
    assert bar == "world"

    # For using the variables from the current environment
    assert ~m(foo bar)s == %{"foo" => "hello", "bar" => "world"}
  end

  test "wrong modifiers raise an ArgumentError" do
    code = quote do: ~m(foo)k
    message = "only these modifiers are supported: s, a"
    assert_raise ArgumentError, message, fn -> Code.eval_quoted(code) end
  end

  test "no interpolation is supported" do
    code = quote do: ~m(foo #{bar} baz)a
    message = "interpolation is not supported with the ~m sigil"
    assert_raise ArgumentError, message, fn -> Code.eval_quoted(code) end
  end

  test "good errors when variables are invalid" do
    code = quote do: ~m(4oo)
    message = "invalid variable name: 4oo"
    assert_raise ArgumentError, message, fn -> Code.eval_quoted(code) end

    code = quote do: ~m($hello!)
    message = "invalid variable name: $hello!"
    assert_raise ArgumentError, message, fn -> Code.eval_quoted(code) end
  end

  defmodule MyStruct do
    defstruct my_field: nil
  end

  test "supports structs" do
    my_field = "hello"
    assert ~m(%MyStruct my_field)a == %MyStruct{my_field: "hello"}
  end

  test "struct syntax can be used in pattern matches" do
    assert ~m(%MyStruct my_field)a = %MyStruct{my_field: "123"}
    assert my_field == "123"
  end

  test "when using structs, fails on non-existing keys" do
    code = quote do: ~m(%MyStruct my_field wat)a = %MyStruct{my_field: 1}
    message = ~r/unknown key :wat for struct ShortMapsTest.MyStruct/
    assert_raise CompileError, message, fn ->
      Code.eval_quoted(code, [], __ENV__)
    end
  end

  test "when using structs, only accepts 'a' modifier and raises for other modifiers" do
    code = quote do
      my_field = "hello"
      ~m(%MyStruct my_field)s
    end
    message = "structs can only consist of atom keys"
    assert_raise ArgumentError, message, fn -> Code.eval_quoted(code) end
  end

  test "when using structs, works with __MODULE__" do
    assert ~m(%__MODULE__.MyStruct my_field)a = %MyStruct{my_field: "hello"}
    assert my_field == "hello"
  end

  defmodule UseInsideStruct do
    defstruct x: nil

    def get_x(~m{%UseInsideStruct x}a), do: x
    def inc_x(~m{%__MODULE__ x}a), do: x+1
  end

  test "can be used with module name within module of the struct" do
    assert UseInsideStruct.get_x(%UseInsideStruct{x: 1}) == 1
  end

  test "can be used with __MODULE__ within module of the struct" do
    assert UseInsideStruct.inc_x(%UseInsideStruct{x: 1}) == 2
  end
end
