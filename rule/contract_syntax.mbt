///|
using @syntax {trait IterVisitor}

///|
fn contract_prefix(name : String, word : String) -> Bool {
  name == word || name.has_prefix(word + "_")
}

///|
priv struct ContractShadows(Array[String])

///|
impl IterVisitor for ContractShadows with fn visit_Binder(self, binder) {
  self.0.push(binder.name)
}

///|
fn contract_file_names(program : @list.List[@syntax.Impl]) -> Array[String] {
  let names = []
  for decl in program {
    match decl {
      TopFuncDef(fun_decl={ type_name: None, name, .. }, ..)
      | TopLetDef(binder=name, ..) => names.push(name.name)
      TopUsing(names=aliases, ..) =>
        for (target, kind) in aliases {
          if kind is Value {
            names.push(target.binder.name)
          }
        }
      _ => ()
    }
  }
  names
}

///|
fn contract_parameter_names(params : @syntax.Parameters?) -> Array[String] {
  let names = []
  if params is Some(params) {
    for param in params {
      match param {
        Positional(binder~, ..)
        | Labelled(binder~, ..)
        | Optional(binder~, ..)
        | QuestionOptional(binder~, ..) => names.push(binder.name)
        DiscardPositional(..) => ()
      }
    }
  }
  names
}

///|
fn contract_callee(expr : @syntax.Expr) -> @syntax.Var? {
  match expr {
    Apply(func=Ident(id~, ..), args~, ..) => {
      for arg in args {
        if arg.value is Hole(kind=Incomplete, ..) {
          return None
        }
      }
      Some(id)
    }
    Pipe(rhs=Ident(id~, ..), ..) | RevPipe(lhs=Ident(id~, ..), ..) => Some(id)
    _ => None
  }
}

///|
fn contract_core_call(
  expr : @syntax.Expr,
  shadows : Array[String],
) -> (String, @basic.Location)? {
  guard contract_callee(expr) is Some({ name, loc, }) else { return None }
  match name {
    Ident(name~) if !shadows.contains(name) => Some((name, loc))
    Dot(pkg="builtin" | "prelude", id~) => Some((id, loc))
    _ => None
  }
}

///|
priv struct ContractBody((@syntax.Expr) -> Unit)

///|
impl IterVisitor for ContractBody with fn visit_Expr(self, expr) {
  (self.0)(expr)
  match expr {
    // A closure or a local function declaration is not an execution of its body.
    Function(..) => ()
    LetFn(body~, ..) | LetAnd(body~, ..) => IterVisitor::visit_Expr(self, body)
    _ => IterVisitor::visit_Expr(IterVisitor::base(self), expr)
  }
}
