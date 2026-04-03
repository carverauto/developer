{base_config_builder, _binding} = Code.eval_file(Path.expand(".credo.base.exs", __DIR__))
{ex_slop_checks, _binding} = Code.eval_file(Path.expand(".credo.ex_slop.exs", __DIR__))
{ex_dna_checks, _binding} = Code.eval_file(Path.expand(".credo.ex_dna.exs", __DIR__))

base_config_builder.(
  extra: ex_slop_checks ++ ex_dna_checks,
  requires: ["deps/ex_dna/lib/ex_dna/integrations/credo.ex"],
  disabled: [
    {Credo.Check.Design.AliasUsage, []},
    {Credo.Check.Design.DuplicatedCode, []},
    {Credo.Check.Design.SkipTestWithoutComment, []},
    {Credo.Check.Readability.AliasOrder, []},
    {Credo.Check.Readability.WithSingleClause, []},
    {Credo.Check.Readability.StrictModuleLayout, []},
    {Credo.Check.Refactor.ABCSize, []},
    {Credo.Check.Refactor.Nesting, []},
    {Credo.Check.Refactor.PipeChainStart, []},
    {Credo.Check.Warning.LeakyEnvironment, []},
    {Credo.Check.Warning.MixEnv, []}
  ]
)
