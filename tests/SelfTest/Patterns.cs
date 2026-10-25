using System.Text.RegularExpressions;

namespace SelfTest;

// Source-generated, so CI can check that the default coverage settings leave generated code (*.g.cs) out.
public static partial class Patterns
{
    [GeneratedRegex("^[0-9]+$")]
    public static partial Regex Digits();
}
