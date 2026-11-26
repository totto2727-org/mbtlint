///|
fn collection_fold_update(expr : @syntax.Expr, accumulator : String) -> Bool {
  match collection_unwrap(expr) {
    Infix(lhs~, rhs~, ..) =>
      collection_name(lhs) == Some(accumulator) &&
      collection_callback(rhs, Some(accumulator))
    _ => false
  }
}

///|
fn collection_fold(expr : @syntax.Expr) -> @basic.Location? {
  match expr {
    ForEach(
      patterns=More(Var(item), tail=Empty),
      expr=source,
      init=More((acc, _), tail=Empty),
      continue_block=Empty,
      body~,
      else_block=Some(last),
      where_clause=None,
      label=None,
      loc~,
    ) if item.name != acc.name &&
      collection_source(source, Some(acc.name)) &&
      collection_name(last) == Some(acc.name) =>
      match collection_unwrap(body) {
        Continue(args=More(step, tail=Empty), label=None, ..) if collection_fold_update(
            step,
            acc.name,
          ) => Some(loc)
        _ => None
      }
    LetMut(
      binder=acc,
      body=Sequence(exprs=More(iteration, tail=Empty), last_expr~, ..),
      ..
    ) if collection_name(last_expr) == Some(acc.name) => {
      guard collection_unwrap(iteration)
        is ForEach(
          patterns=More(Var(item), tail=Empty),
          expr=source,
          init=Empty,
          continue_block=Empty,
          body~,
          else_block=None,
          where_clause=None,
          label=None,
          loc~,
        ) &&
        item.name != acc.name &&
        collection_source(source, Some(acc.name)) else {
        return None
      }
      guard collection_unwrap(body)
        is Assign(var_={ name: Ident(name~), .. }, expr=step, augmented_by~, ..) &&
        name == acc.name else {
        return None
      }
      let eligible = match augmented_by {
        Some(_) => collection_callback(step, Some(acc.name))
        None => collection_fold_update(step, acc.name)
      }
      if eligible {
        Some(loc)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
pub fn prefer_collection_fold() -> @core.Rule {
  builtin_rule("prefer-collection-fold", ctx => {
    @core.Listener(on_expr=expr => {
      if collection_fold(expr) is Some(loc) {
        (ctx.report)(
          loc, "Consider fold to compute this accumulator from the items in order.",
        )
      }
    })
  })
}
