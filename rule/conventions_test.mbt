///|
fn assert_convention_lines(
  rule : @core.Rule,
  source : String,
  expected : Array[Int32],
) -> Unit raise {
  let diagnostics = @core.Config()
    .with_rule(rule)
    .lint(path="sample.mbt", source~)
  assert_eq(
    diagnostics.map(diagnostic => {
      (diagnostic.rule_id, diagnostic.loc.start.lnum)
    }),
    expected.map(line => (Some(rule.id), line)),
  )
}

///|
test "require-public-docs - checks exported declarations but accepts attached docstrings" {
  let source =
    #|pub fn undocumented() -> Int { 1 }
    #|///|
    #|/// Return a known value.
    #|pub fn documented() -> Int { 2 }
    #|fn internal() -> Int { 3 }
    #|pub struct Record { value : Int }
    #|pub const Answer : Int = 42
    #|///|
    #|pub fn Record::read(self : Record) -> Int { self.value }
    #|// This is not documentation.
    #|pub trait Reader { read(Self) -> Int }
  assert_convention_lines(@rule.require_public_docs(), source, [1, 6, 7, 9, 11])
}

///|
test "prefer-labelled-parameters - counts caller arguments and skips foreign or trait contracts" {
  let source =
    #|fn calculate(a : Int, b~ : Int, c~ : Int, d~ : Int) -> Int { a + b + c + d }
    #|fn labelled(a~ : Int, b~ : Int, c~ : Int = 0, d? : Int) -> Unit {}
    #|fn short(a : Int, b : Int, c : Int) -> Unit {}
    #|fn Widget::short(widget : Widget, a : Int, b : Int, c : Int) -> Unit {}
    #|fn Widget::long(widget : Widget, a : Int, b~ : Int, c~ : Int, d~ : Int) -> Unit {}
    #|fn Widget::long_labelled(widget : Widget, a~ : Int, b~ : Int, c~ : Int, d~ : Int) -> Unit {}
    #|fn Widget::static(a : Int, b : Int, c : Int, d : Int) -> Unit {}
    #|fn Widget::Widget(original : Widget, a : Int, b : Int, c : Int) -> Widget { original }
    #|extern "C" fn native(a : Int, b : Int, c : Int, d : Int) = "native"
    #|impl Factory for Widget with fn create(a, b, c, d) { a }
  assert_convention_lines(@rule.prefer_labelled_parameters(), source, [
    1, 5, 7, 8,
  ])
}

///|
test "prefer-arrow-callback - sees direct callbacks but preserves named and explicitly typed functions" {
  let source =
    #|fn example(items : Array[Int]) -> Unit {
    #|  consume(fn(x) { x + 1 })
    #|  items.each((fn(x) { println(x) }))
    #|  consume(x => x + 1)
    #|  consume(fn(x : Int) { x + 1 })
    #|  consume(fn(x) -> Int { x + 1 })
    #|  consume(async fn(x) { x })
    #|  consume(fn(x) raise MyError { x })
    #|  let helper = fn(x) { x + 1 }
    #|  consume(helper)
    #|}
  assert_convention_lines(@rule.prefer_arrow_callback(), source, [2, 3])
}

///|
test "no-manual-path-join - checks known filesystem paths without matching content or URIs" {
  let source =
    #|fn example(parent : String, child : String) -> Unit raise {
    #|  @fs.read_file_to_string(parent + "/" + child)
    #|  @fs.path_exists(parent + ("/" + child))
    #|  @fs.read_file_to_bytes(parent + "\\" + child)
    #|  @fs.write_string_to_file(path, parent + "/" + child)
    #|  @fs.read_file_to_string(@path.join(parent, child))
    #|  @fs.read_file_to_string("directory/file.txt")
    #|  @fs.path_exists(parent + "/")
    #|  @network.fetch(parent + "/" + child)
    #|  read_file_to_string(parent + "/" + child)
    #|}
  assert_convention_lines(@rule.no_manual_path_join(), source, [2, 3, 4])
}

///|
test "require-named-tests - distinguishes anonymous and blank tests from ordinary names" {
  let source =
    #|test {}
    #|test "   " {}
    #|test "" {}
    #|test "Widget create - with distinct inputs" {}
    #|test "panic_Widget create - with invalid input" {}
  assert_convention_lines(@rule.require_named_tests(), source, [1, 2, 3])
}

///|
test "no-redundant-rethrow - reports unchanged errors but preserves recovery and translation" {
  let source =
    #|fn direct() -> Int raise { try { action() } catch { err => raise err } }
    #|fn translated() -> Int raise { try { action() } catch { err => raise Wrapped(err) } }
    #|fn recovered() -> Int { try { action() } catch { _ => 0 } }
    #|fn recorded() -> Int raise {
    #|  try { action() } catch { err => { log(err); raise err } }
    #|}
    #|fn partial() -> Int raise {
    #|  try { action() } catch { Known => 0; err => raise err }
    #|}
    #|fn filtered() -> Int raise {
    #|  try { action() } catch { err if is_retryable(err) => raise err }
    #|}
    #|fn successful() -> Int raise {
    #|  try { action() } catch { err => raise err } noraise { value => value + 1 }
    #|}
  assert_convention_lines(@rule.no_redundant_rethrow(), source, [1])
}
