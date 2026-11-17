import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Paleta leve para o renderer RichAiText. Adapta o componente do projeto de
/// referência às cores do BrowseIt sem depender do tema do outro aplicativo.
class BrowseRichTextPalette {
  const BrowseRichTextPalette({
    required this.isDark,
    required this.primary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.pageBackground,
    required this.hover,
  });

  final bool isDark;
  final Color primary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color pageBackground;
  final Color hover;

  factory BrowseRichTextPalette.fromContext(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BrowseRichTextPalette(
      isDark: dark,
      primary: accentColor(context),
      onSurface: mainText(context),
      onSurfaceVariant: mutedText(context),
      outline: lineColor(context),
      pageBackground: pageBg(context),
      hover: pillColor(context),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SÍMBOLOS MATEMÁTICOS — tabelas de tradução LaTeX → unicode
// ══════════════════════════════════════════════════════════════

const Map<String, String> kGreekLetters = {
  r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
  r'\epsilon': 'ε', r'\varepsilon': 'ε', r'\zeta': 'ζ', r'\eta': 'η',
  r'\theta': 'θ', r'\vartheta': 'ϑ', r'\iota': 'ι', r'\kappa': 'κ',
  r'\lambda': 'λ', r'\mu': 'μ', r'\nu': 'ν', r'\xi': 'ξ',
  r'\omicron': 'ο', r'\pi': 'π', r'\varpi': 'ϖ', r'\rho': 'ρ',
  r'\varrho': 'ϱ', r'\sigma': 'σ', r'\varsigma': 'ς', r'\tau': 'τ',
  r'\upsilon': 'υ', r'\phi': 'φ', r'\varphi': 'φ', r'\chi': 'χ',
  r'\psi': 'ψ', r'\omega': 'ω',
  r'\Alpha': 'Α', r'\Beta': 'Β', r'\Gamma': 'Γ', r'\Delta': 'Δ',
  r'\Epsilon': 'Ε', r'\Zeta': 'Ζ', r'\Eta': 'Η', r'\Theta': 'Θ',
  r'\Iota': 'Ι', r'\Kappa': 'Κ', r'\Lambda': 'Λ', r'\Mu': 'Μ',
  r'\Nu': 'Ν', r'\Xi': 'Ξ', r'\Omicron': 'Ο', r'\Pi': 'Π',
  r'\Rho': 'Ρ', r'\Sigma': 'Σ', r'\Tau': 'Τ', r'\Upsilon': 'Υ',
  r'\Phi': 'Φ', r'\Chi': 'Χ', r'\Psi': 'Ψ', r'\Omega': 'Ω',
};

const Map<String, String> kMathSymbols = {
  r'\times': '×', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
  r'\cdot': '·', r'\ast': '∗', r'\star': '⋆', r'\circ': '∘',
  r'\bullet': '•', r'\oplus': '⊕', r'\otimes': '⊗', r'\ominus': '⊖',
  r'\odot': '⊙', r'\oslash': '⊘', r'\uplus': '⊎',
  r'\leq': '≤', r'\le': '≤', r'\geq': '≥', r'\ge': '≥',
  r'\neq': '≠', r'\ne': '≠', r'\approx': '≈', r'\equiv': '≡',
  r'\sim': '∼', r'\simeq': '≃', r'\cong': '≅', r'\propto': '∝',
  r'\ll': '≪', r'\gg': '≫', r'\prec': '≺', r'\succ': '≻',
  r'\preceq': '≼', r'\succeq': '≽', r'\subset': '⊂', r'\subseteq': '⊆',
  r'\supset': '⊃', r'\supseteq': '⊇', r'\in': '∈', r'\notin': '∉',
  r'\ni': '∋', r'\not\ni': '∌', r'\mid': '∣', r'\nmid': '∤',
  r'\parallel': '∥', r'\nparallel': '∦', r'\perp': '⊥',
  r'\rightarrow': '→', r'\to': '→', r'\leftarrow': '←',
  r'\leftrightarrow': '↔', r'\Rightarrow': '⇒', r'\Leftarrow': '⇐',
  r'\Leftrightarrow': '⇔', r'\mapsto': '↦', r'\uparrow': '↑',
  r'\downarrow': '↓', r'\nearrow': '↗', r'\searrow': '↘',
  r'\swarrow': '↙', r'\nwarrow': '↖', r'\longrightarrow': '⟶',
  r'\longleftarrow': '⟵', r'\longleftrightarrow': '⟷',
  r'\Longrightarrow': '⟹', r'\Longleftarrow': '⟸',
  r'\Longleftrightarrow': '⟺', r'\hookrightarrow': '↪',
  r'\hookleftarrow': '↩', r'\rightharpoonup': '⇀',
  r'\rightharpoondown': '⇁', r'\leftharpoonup': '↼',
  r'\leftharpoondown': '↽',
  r'\forall': '∀', r'\exists': '∃', r'\nexists': '∄',
  r'\neg': '¬', r'\lnot': '¬', r'\land': '∧', r'\wedge': '∧',
  r'\lor': '∨', r'\vee': '∨', r'\top': '⊤', r'\bot': '⊥',
  r'\emptyset': '∅', r'\varnothing': '∅', r'\cup': '∪', r'\cap': '∩',
  r'\setminus': '∖', r'\complement': '∁',
  r'\infty': '∞', r'\partial': '∂', r'\nabla': '∇', r'\hbar': 'ℏ',
  r'\ell': 'ℓ', r'\imath': 'ı', r'\jmath': 'ȷ',
  r'\int': '∫', r'\iint': '∬', r'\iiint': '∭', r'\oint': '∮',
  r'\sum': '∑', r'\prod': '∏', r'\coprod': '∐',
  r'\angle': '∠', r'\measuredangle': '∡', r'\sphericalangle': '∢',
  r'\degree': '°', r'\prime': '′', r'\backprime': '‵',
  r'\therefore': '∴', r'\because': '∵', r'\cdots': '⋯',
  r'\ldots': '…', r'\vdots': '⋮', r'\ddots': '⋱', r'\iddots': '⋰',
  r'\implies': '⟹', r'\impliedby': '⟸', r'\iff': '⟺',
  r'\mathbb{R}': 'ℝ', r'\mathbb{N}': 'ℕ', r'\mathbb{Z}': 'ℤ',
  r'\mathbb{Q}': 'ℚ', r'\mathbb{C}': 'ℂ', r'\mathbb{H}': 'ℍ',
  r'\mathbb{O}': '𝕆',
  r'\lvert': '|', r'\rvert': '|', r'\lVert': '‖', r'\rVert': '‖',
  r'\langle': '⟨', r'\rangle': '⟩', r'\lceil': '⌈', r'\rceil': '⌉',
  r'\lfloor': '⌊', r'\rfloor': '⌋', r'\lbrace': '{', r'\rbrace': '}',
  r'\hat': '', r'\bar': '', r'\vec': '', r'\dot': '', r'\ddot': '',
  r'\tilde': '', r'\overline': '', r'\underline': '', r'\boxed': '',
  r'\square': '□', r'\blacksquare': '■', r'\triangle': '△',
  r'\bigtriangleup': '△', r'\bigtriangledown': '▽', r'\lozenge': '◊',
  r'\diamond': '◆', r'\clubsuit': '♣', r'\diamondsuit': '♦',
  r'\heartsuit': '♥', r'\spadesuit': '♠',
  r'\,': ' ', r'\;': '  ', r'\:': ' ', r'\!': '', r'\quad': '   ',
  r'\qquad': '      ', r'\ ': ' ',
};

// Operadores/funções nomeadas do LaTeX — cobertura extensa (álgebra,
// trigonometria, cálculo, álgebra linear, estatística, lógica).
const Map<String, String> kMathNamedOperators = {
  r'\sin': 'sin', r'\cos': 'cos', r'\tan': 'tan', r'\cot': 'cot',
  r'\sec': 'sec', r'\csc': 'csc',
  r'\arcsin': 'arcsin', r'\arccos': 'arccos', r'\arctan': 'arctan',
  r'\sinh': 'sinh', r'\cosh': 'cosh', r'\tanh': 'tanh',
  r'\coth': 'coth', r'\operatorname{sech}': 'sech', r'\operatorname{csch}': 'csch',
  r'\log': 'log', r'\ln': 'ln', r'\lg': 'lg', r'\exp': 'exp',
  r'\lim': 'lim', r'\limsup': 'limsup', r'\liminf': 'liminf',
  r'\max': 'max', r'\min': 'min', r'\sup': 'sup', r'\inf': 'inf',
  r'\arg': 'arg', r'\det': 'det', r'\dim': 'dim', r'\ker': 'ker',
  r'\gcd': 'gcd', r'\lcm': 'lcm', r'\deg': 'deg', r'\hom': 'hom',
  r'\mod': 'mod', r'\bmod': 'mod', r'\pmod': 'mod',
  r'\Pr': 'Pr', r'\Var': 'Var', r'\Cov': 'Cov', r'\E': 'E',
  r'\rank': 'rank', r'\trace': 'tr', r'\tr': 'tr',
  r'\mathrm{d}': 'd', r'\mathrm{e}': 'e', r'\mathrm{i}': 'i',
};

const Set<String> kMathFormattingCommands = {
  r'\text', r'\mathrm', r'\mathbf', r'\mathit', r'\mathsf', r'\mathtt',
  r'\mathcal', r'\mathbb', r'\mathfrak', r'\mathscr', r'\operatorname',
  r'\overrightarrow', r'\overleftarrow', r'\overline', r'\underline',
  r'\boxed', r'\color', r'\textcolor',
};

const Map<String, String> kSuperscriptDigits = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
  'n': 'ⁿ', 'i': 'ⁱ',
};

const Map<String, String> kSubscriptDigits = {
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
  '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
  '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
  'a': 'ₐ', 'e': 'ₑ', 'o': 'ₒ', 'x': 'ₓ', 'h': 'ₕ',
  'k': 'ₖ', 'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'p': 'ₚ',
  's': 'ₛ', 't': 'ₜ',
};

String? _toSuperscriptUnicode(String s) {
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    final mapped = kSuperscriptDigits[ch];
    if (mapped == null) return null;
    buf.write(mapped);
  }
  return buf.toString();
}

String? _toSubscriptUnicode(String s) {
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    final mapped = kSubscriptDigits[ch];
    if (mapped == null) return null;
    buf.write(mapped);
  }
  return buf.toString();
}

const Map<String, String> kEmojiShortcodes = {};

sealed class _MathAtom {}

class _MathText extends _MathAtom {
  final String text;
  final bool italic;
  _MathText(this.text, {this.italic = true});
}

class _MathFraction extends _MathAtom {
  final String numerator;
  final String denominator;
  _MathFraction(this.numerator, this.denominator);
}

class _MathSqrt extends _MathAtom {
  final String content;
  final String? index;
  _MathSqrt(this.content, {this.index});
}

class _MathOverline extends _MathAtom {
  final String content;
  _MathOverline(this.content);
}

class _MathUnderline extends _MathAtom {
  final String content;
  _MathUnderline(this.content);
}

class _MathBoxed extends _MathAtom {
  final String content;
  _MathBoxed(this.content);
}

class _MathColor extends _MathAtom {
  final String color;
  final String content;
  _MathColor(this.color, this.content);
}

class _MathAccent extends _MathAtom {
  final String accent;
  final String content;
  _MathAccent(this.accent, this.content);
}

class _MathArrow extends _MathAtom {
  final String direction;
  final String content;
  _MathArrow(this.direction, this.content);
}

class _MathBinom extends _MathAtom {
  final String top;
  final String bottom;
  _MathBinom(this.top, this.bottom);
}

class _MathOverbrace extends _MathAtom {
  final String content;
  final String? annotation;
  _MathOverbrace(this.content, {this.annotation});
}

class _MathUnderbrace extends _MathAtom {
  final String content;
  final String? annotation;
  _MathUnderbrace(this.content, {this.annotation});
}

class _MathXArrow extends _MathAtom {
  final String direction;
  final String content;
  final String label;
  _MathXArrow(this.direction, this.content, this.label);
}

class _MathOverset extends _MathAtom {
  final String label;
  final String content;
  _MathOverset(this.label, this.content);
}

class _MathUnderset extends _MathAtom {
  final String label;
  final String content;
  _MathUnderset(this.label, this.content);
}

class _MathLimits extends _MathAtom {
  final String? sub;
  final String? sup;
  final String symbol;
  _MathLimits(this.symbol, {this.sub, this.sup});
}

class _MathNot extends _MathAtom {
  final String content;
  _MathNot(this.content);
}

String _stripOuterBraces(String s) {
  s = s.trim();
  if (s.startsWith('{') && s.endsWith('}')) {
    return s.substring(1, s.length - 1).trim();
  }
  return s;
}

String _substituteKnownTokens(String expr) {
  var result = expr;
  final allTokens = <String, String>{
    ...kGreekLetters,
    ...kMathSymbols,
    ...kMathNamedOperators,
  };
  final sortedKeys = allTokens.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final token in sortedKeys) {
    result = result.replaceAll(token, allTokens[token]!);
  }
  result = result.replaceAll('{,}', ',');
  return result;
}

String _resolveSuperSubscripts(String expr) {
  var result = expr;

  result = result.replaceAllMapped(
    RegExp(r'\^\{([^{}]+)\}'),
    (m) {
      final sup = _toSuperscriptUnicode(m.group(1)!);
      return sup ?? '\u0001SUP{${m.group(1)}}\u0001';
    },
  );
  result = result.replaceAllMapped(
    RegExp(r'_\{([^{}]+)\}'),
    (m) {
      final sub = _toSubscriptUnicode(m.group(1)!);
      return sub ?? '\u0001SUB{${m.group(1)}}\u0001';
    },
  );

  result = result.replaceAllMapped(
    RegExp(r'\^([a-zA-Z0-9+\-=()])'),
    (m) {
      final sup = _toSuperscriptUnicode(m.group(1)!);
      return sup ?? '\u0001SUP{${m.group(1)}}\u0001';
    },
  );
  result = result.replaceAllMapped(
    RegExp(r'_([a-zA-Z0-9+\-=()])'),
    (m) {
      final sub = _toSubscriptUnicode(m.group(1)!);
      return sub ?? '\u0001SUB{${m.group(1)}}\u0001';
    },
  );

  return result;
}

String _resolveFormattingCommands(String expr) {
  var result = expr;

  result = result.replaceAllMapped(
    RegExp(r'\\text\{([^{}]+)\}'),
    (m) => '\u0002TXT{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\mathrm\{([^{}]+)\}'),
    (m) => '\u0002TXT{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\mathbf\{([^{}]+)\}'),
    (m) => '\u0002BF{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\mathit\{([^{}]+)\}'),
    (m) => '\u0002IT{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\mathsf\{([^{}]+)\}'),
    (m) => '\u0002SF{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\mathtt\{([^{}]+)\}'),
    (m) => '\u0002TT{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\mathcal\{([^{}]+)\}'),
    (m) => '\u0002IT{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\mathbb\{([^{}]+)\}'),
    (m) => '\u0002BF{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\mathfrak\{([^{}]+)\}'),
    (m) => '\u0002IT{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\mathscr\{([^{}]+)\}'),
    (m) => '\u0002IT{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\operatorname\{([^{}]+)\}'),
    (m) => '\u0002TXT{${m.group(1)}}\u0002',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\overrightarrow\{([^{}]+)\}'),
    (m) => '\u0003OVER{${m.group(1)}}\u0003',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\overleftarrow\{([^{}]+)\}'),
    (m) => '\u0003UNDER{${m.group(1)}}\u0003',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\overline\{([^{}]+)\}'),
    (m) => '\u0004OVERLINE{${m.group(1)}}\u0004',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\underline\{([^{}]+)\}'),
    (m) => '\u0004UNDERLINE{${m.group(1)}}\u0004',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\boxed\{([^{}]+)\}'),
    (m) => '\u0005BOXED{${m.group(1)}}\u0005',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\color\{([^{}]+)\}\{([^{}]+)\}'),
    (m) => '\u0006COLOR{${m.group(1)}}{${m.group(2)}}\u0006',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\textcolor\{([^{}]+)\}\{([^{}]+)\}'),
    (m) => '\u0006COLOR{${m.group(1)}}{${m.group(2)}}\u0006',
  );

  for (final acc in ['hat', 'bar', 'vec', 'dot', 'ddot', 'tilde']) {
    result = result.replaceAllMapped(
      RegExp(r'\\' + acc + r'\{([^{}]+)\}'),
      (m) => '\u0007ACC{$acc}{${m.group(1)}}\u0007',
    );
  }

  result = result.replaceAllMapped(
    RegExp(r'\\not\s*(\S)'),
    (m) => '\u0008NOT{${m.group(1)}}\u0008',
  );

  return result;
}

List<_MathAtom> _parseMathExpression(String raw) {
  var expr = _substituteKnownTokens(raw);
  expr = _resolveSuperSubscripts(expr);
  expr = _resolveFormattingCommands(expr);

  final atoms = <_MathAtom>[];
  final combinedPattern = RegExp(
    r'\\frac\{([^{}]+)\}\{([^{}]+)\}'
    r'|\\sqrt(\[([^\]]+)\])?\{([^{}]+)\}'
    r'|\\binom\{([^{}]+)\}\{([^{}]+)\}'
    r'|\\overbrace\{([^{}]+)\}\^?\{?([^{}]*)\}?'
    r'|\\underbrace\{([^{}]+)\}_?\{?([^{}]*)\}?'
    r'|\\overset\{([^{}]+)\}\{([^{}]+)\}'
    r'|\\underset\{([^{}]+)\}\{([^{}]+)\}'
    r'|\\xrightarrow\s*(?:\[([^\]]*)\])?\{([^{}]+)\}'
    r'|\\xleftarrow\s*(?:\[([^\]]*)\])?\{([^{}]+)\}'
    r'|\\sum\\limits_\{([^{}]+)\}\^\{([^{}]+)\}'
    r'|\\sum\\limits\^\{([^{}]+)\}_\{([^{}]+)\}'
    r'|\\sum\\limits_\{([^{}]+)\}'
    r'|\\sum\\limits\^\{([^{}]+)\}'
    r'|\\prod\\limits_\{([^{}]+)\}\^\{([^{}]+)\}'
    r'|\\prod\\limits\^\{([^{}]+)\}_\{([^{}]+)\}'
    r'|\\prod\\limits_\{([^{}]+)\}'
    r'|\\prod\\limits\^\{([^{}]+)\}'
    r'|\\int\\limits_\{([^{}]+)\}\^\{([^{}]+)\}'
    r'|\\int\\limits\^\{([^{}]+)\}_\{([^{}]+)\}'
    r'|\\int\\limits_\{([^{}]+)\}'
    r'|\\int\\limits\^\{([^{}]+)\}'
    r'|\\lim_\{([^{}]+)\}'
    r'|\\max_\{([^{}]+)\}'
    r'|\\min_\{([^{}]+)\}'
    r'|\u0004OVERLINE\{([^{}]+)\}\u0004'
    r'|\u0004UNDERLINE\{([^{}]+)\}\u0004'
    r'|\u0005BOXED\{([^{}]+)\}\u0005'
    r'|\u0006COLOR\{([^{}]+)\}\{([^{}]+)\}\u0006'
    r'|\u0007ACC\{([^{}]+)\}\{([^{}]+)\}\u0007'
    r'|\u0008NOT\{([^{}]+)\}\u0008'
    r'|\u0003OVER\{([^{}]+)\}\u0003'
    r'|\u0003UNDER\{([^{}]+)\}\u0003',
  );

  int last = 0;
  for (final m in combinedPattern.allMatches(expr)) {
    if (m.start > last) {
      atoms.addAll(_parsePlainMathText(expr.substring(last, m.start)));
    }
    final match = m.group(0)!;
    if (match.startsWith(r'\frac')) {
      atoms.add(_MathFraction(m.group(1)!, m.group(2)!));
    } else if (match.startsWith(r'\sqrt')) {
      atoms.add(_MathSqrt(m.group(5)!, index: m.group(4)));
    } else if (match.startsWith(r'\binom')) {
      atoms.add(_MathBinom(m.group(6)!, m.group(7)!));
    } else if (match.startsWith(r'\overbrace')) {
      atoms.add(_MathOverbrace(m.group(8)!, annotation: m.group(9)?.isEmpty ?? true ? null : m.group(9)));
    } else if (match.startsWith(r'\underbrace')) {
      atoms.add(_MathUnderbrace(m.group(10)!, annotation: m.group(11)?.isEmpty ?? true ? null : m.group(11)));
    } else if (match.startsWith(r'\overset')) {
      atoms.add(_MathOverset(m.group(12)!, m.group(13)!));
    } else if (match.startsWith(r'\underset')) {
      atoms.add(_MathUnderset(m.group(14)!, m.group(15)!));
    } else if (match.startsWith(r'\xrightarrow')) {
      atoms.add(_MathXArrow('right', m.group(16)!, m.group(17)!));
    } else if (match.startsWith(r'\xleftarrow')) {
      atoms.add(_MathXArrow('left', m.group(18)!, m.group(19)!));
    } else if (match.startsWith(r'\sum')) {
      final sub = m.group(20) ?? m.group(22) ?? m.group(24) ?? m.group(26);
      final sup = m.group(21) ?? m.group(23) ?? m.group(25) ?? m.group(27);
      atoms.add(_MathLimits('∑', sub: sub, sup: sup));
    } else if (match.startsWith(r'\prod')) {
      final sub = m.group(28) ?? m.group(30) ?? m.group(32) ?? m.group(34);
      final sup = m.group(29) ?? m.group(31) ?? m.group(33) ?? m.group(35);
      atoms.add(_MathLimits('∏', sub: sub, sup: sup));
    } else if (match.startsWith(r'\int')) {
      final sub = m.group(36) ?? m.group(38) ?? m.group(40) ?? m.group(42);
      final sup = m.group(37) ?? m.group(39) ?? m.group(41) ?? m.group(43);
      atoms.add(_MathLimits('∫', sub: sub, sup: sup));
    } else if (match.startsWith(r'\lim_')) {
      atoms.add(_MathLimits('lim', sub: m.group(44)));
    } else if (match.startsWith(r'\max_')) {
      atoms.add(_MathLimits('max', sub: m.group(45)));
    } else if (match.startsWith(r'\min_')) {
      atoms.add(_MathLimits('min', sub: m.group(46)));
    } else if (match.startsWith('\u0004OVERLINE')) {
      atoms.add(_MathOverline(m.group(47)!));
    } else if (match.startsWith('\u0004UNDERLINE')) {
      atoms.add(_MathUnderline(m.group(48)!));
    } else if (match.startsWith('\u0005BOXED')) {
      atoms.add(_MathBoxed(m.group(49)!));
    } else if (match.startsWith('\u0006COLOR')) {
      atoms.add(_MathColor(m.group(50)!, m.group(51)!));
    } else if (match.startsWith('\u0007ACC')) {
      atoms.add(_MathAccent(m.group(52)!, m.group(53)!));
    } else if (match.startsWith('\u0008NOT')) {
      atoms.add(_MathNot(m.group(54)!));
    } else if (match.startsWith('\u0003OVER')) {
      atoms.add(_MathArrow('over', m.group(55)!));
    } else if (match.startsWith('\u0003UNDER')) {
      atoms.add(_MathArrow('under', m.group(56)!));
    }
    last = m.end;
  }
  if (last < expr.length) {
    atoms.addAll(_parsePlainMathText(expr.substring(last)));
  }
  return atoms;
}

List<_MathAtom> _parsePlainMathText(String text) {
  if (text.isEmpty) return const [];
  final atoms = <_MathAtom>[];

  final pattern = RegExp(
    r'\u0002(?:TXT|BF|IT|SF|TT)\{([^{}]+)\}\u0002',
  );
  int last = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > last) {
      final plain = text.substring(last, m.start);
      if (plain.isNotEmpty) atoms.add(_MathText(plain));
    }
    final type = m.group(0)!.substring(1, m.group(0)!.indexOf('{') - 1);
    final content = m.group(1)!;
    switch (type) {
      case 'TXT':
        atoms.add(_MathText(content, italic: false));
        break;
      case 'BF':
        atoms.add(_MathText(content, italic: false));
        break;
      case 'IT':
        atoms.add(_MathText(content, italic: true));
        break;
      case 'SF':
        atoms.add(_MathText(content, italic: false));
        break;
      case 'TT':
        atoms.add(_MathText(content, italic: false));
        break;
      default:
        atoms.add(_MathText(content));
    }
    last = m.end;
  }
  if (last < text.length) {
    final remaining = text.substring(last);
    if (remaining.isNotEmpty) atoms.add(_MathText(remaining));
  }
  return atoms;
}

List<InlineSpan> _renderMathTextWithMarkers(String text, TextStyle baseStyle) {
  final spans = <InlineSpan>[];
  final markerPattern = RegExp(r'\u0001(SUP|SUB)\{([^}]*)\}\u0001');
  int last = 0;
  for (final m in markerPattern.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: baseStyle));
    }
    final isSup = m.group(1) == 'SUP';
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.top,
      baseline: TextBaseline.alphabetic,
      child: Transform.translate(
        offset: Offset(0, isSup ? -baseStyle.fontSize! * 0.35 : baseStyle.fontSize! * 0.15),
        child: Text(
          m.group(2)!,
          style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.68),
        ),
      ),
    ));
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: baseStyle));
  }
  return spans;
}

class MathInline extends StatelessWidget {
  final String expression;
  final BrowseRichTextPalette s;
  final bool block;
  const MathInline({
    super.key,
    required this.expression,
    required this.s,
    this.block = false,
  });

  @override
  Widget build(BuildContext context) {
    final atoms = _parseMathExpression(expression);
    final baseFontSize = block ? 17.0 : 15.5;
    final baseStyle = TextStyle(
      color: s.onSurface,
      fontSize: baseFontSize,
      fontStyle: FontStyle.italic,
      height: 1.3,
    );

    final rowChildren = <Widget>[];
    for (final atom in atoms) {
      switch (atom) {
        case _MathText(:final text, :final italic):
          if (text.isEmpty) continue;
          final style = baseStyle.copyWith(
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          );
          rowChildren.add(RichText(
            text: TextSpan(children: _renderMathTextWithMarkers(text, style)),
          ));
        case _MathFraction(:final numerator, :final denominator):
          rowChildren.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(numerator,
                    style: baseStyle.copyWith(fontSize: baseFontSize * 0.82)),
                Container(
                  height: 1.2,
                  width: _estimateFracWidth(numerator, denominator, baseFontSize),
                  color: s.onSurface,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                ),
                Text(denominator,
                    style: baseStyle.copyWith(fontSize: baseFontSize * 0.82)),
              ],
            ),
          ));
        case _MathSqrt(:final content, :final index):
          rowChildren.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index != null)
                  Transform.translate(
                    offset: const Offset(2, 4),
                    child: Text(index,
                        style: baseStyle.copyWith(fontSize: baseFontSize * 0.55)),
                  ),
                Text('√', style: baseStyle.copyWith(fontSize: baseFontSize * 1.05)),
                Container(
                  margin: const EdgeInsets.only(top: 1),
                  padding: const EdgeInsets.only(top: 1, left: 1, right: 2),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: s.onSurface, width: 1)),
                  ),
                  child: Text(content, style: baseStyle),
                ),
              ],
            ),
          ));
        case _MathOverline(:final content):
          rowChildren.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(content, style: baseStyle),
                Container(height: 1.2, width: content.length * baseFontSize * 0.56, color: s.onSurface),
              ],
            ),
          ));
        case _MathUnderline(:final content):
          rowChildren.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(content, style: baseStyle.copyWith(decoration: TextDecoration.underline)),
          ));
        case _MathBoxed(:final content):
          rowChildren.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: s.onSurface, width: 1),
              borderRadius: BorderRadius.zero,
            ),
            child: Text(content, style: baseStyle),
          ));
        case _MathColor(:final color, :final content):
          rowChildren.add(Text(
            content,
            style: baseStyle.copyWith(color: _parseColor(color, s)),
          ));
        case _MathAccent(:final accent, :final content):
          rowChildren.add(_buildAccent(accent, content, baseStyle));
        case _MathArrow(:final direction, :final content):
          rowChildren.add(_buildArrow(direction, content, baseStyle));
        case _MathBinom(:final top, :final bottom):
          rowChildren.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('(', style: baseStyle.copyWith(fontSize: baseFontSize * 1.2)),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(top, style: baseStyle.copyWith(fontSize: baseFontSize * 0.82)),
                    Text(bottom, style: baseStyle.copyWith(fontSize: baseFontSize * 0.82)),
                  ],
                ),
                Text(')', style: baseStyle.copyWith(fontSize: baseFontSize * 1.2)),
              ],
            ),
          ));
        case _MathOverbrace(:final content, :final annotation):
          rowChildren.add(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (annotation != null)
                Text(annotation, style: baseStyle.copyWith(fontSize: baseFontSize * 0.7)),
              Text('⏞', style: baseStyle.copyWith(fontSize: baseFontSize * 1.2)),
              Text(content, style: baseStyle),
            ],
          ));
        case _MathUnderbrace(:final content, :final annotation):
          rowChildren.add(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content, style: baseStyle),
              Text('⏟', style: baseStyle.copyWith(fontSize: baseFontSize * 1.2)),
              if (annotation != null)
                Text(annotation, style: baseStyle.copyWith(fontSize: baseFontSize * 0.7)),
            ],
          ));
        case _MathXArrow(:final direction, :final content, :final label):
          rowChildren.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.isEmpty
                    ? (direction == 'left' ? '⟵' : '⟶')
                    : label,
                  style: baseStyle.copyWith(fontSize: baseFontSize * 0.75)),
                Text(content, style: baseStyle),
              ],
            ),
          ));
        case _MathOverset(:final label, :final content):
          rowChildren.add(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: baseStyle.copyWith(fontSize: baseFontSize * 0.7)),
              Text(content, style: baseStyle),
            ],
          ));
        case _MathUnderset(:final label, :final content):
          rowChildren.add(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content, style: baseStyle),
              Text(label, style: baseStyle.copyWith(fontSize: baseFontSize * 0.7)),
            ],
          ));
        case _MathLimits(:final symbol, :final sub, :final sup):
          rowChildren.add(Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (sup != null)
                Text(sup, style: baseStyle.copyWith(fontSize: baseFontSize * 0.65)),
              Text(symbol, style: baseStyle.copyWith(
                fontSize: baseFontSize * (symbol.length > 1 ? 1.0 : 1.3),
                fontStyle: symbol.length > 1 ? FontStyle.normal : FontStyle.italic,
              )),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(left: 1),
                  child: Text(sub, style: baseStyle.copyWith(fontSize: baseFontSize * 0.65)),
                ),
            ],
          ));
        case _MathNot(:final content):
          rowChildren.add(Stack(
            alignment: Alignment.center,
            children: [
              Text(content, style: baseStyle),
              Container(
                width: content.length * baseFontSize * 0.5,
                height: 1.2,
                color: s.onSurface,
                transform: Matrix4.skewY(-0.3),
              ),
            ],
          ));
      }
    }

    final content = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: rowChildren,
    );

    if (!block) return content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: s.hover,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(child: content),
      ),
    );
  }

  Widget _buildAccent(String accent, String content, TextStyle baseStyle) {
    switch (accent) {
      case 'hat':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('^', style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.7)),
            Text(content, style: baseStyle),
          ],
        );
      case 'bar':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: content.length * baseStyle.fontSize! * 0.55, height: 1, color: baseStyle.color),
            Text(content, style: baseStyle),
          ],
        );
      case 'vec':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('→', style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.7)),
            Text(content, style: baseStyle),
          ],
        );
      case 'dot':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('˙', style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.8)),
            Text(content, style: baseStyle),
          ],
        );
      case 'ddot':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¨', style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.7)),
            Text(content, style: baseStyle),
          ],
        );
      case 'tilde':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('~', style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.7)),
            Text(content, style: baseStyle),
          ],
        );
      default:
        return Text(content, style: baseStyle);
    }
  }

  Widget _buildArrow(String direction, String content, TextStyle baseStyle) {
    final arrow = direction == 'over' ? '⟶' : '⟵';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (direction == 'over') ...[
          Text(arrow, style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.8)),
          Text(content, style: baseStyle),
        ] else ...[
          Text(content, style: baseStyle),
          Text(arrow, style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.8)),
        ],
      ],
    );
  }

  Color _parseColor(String colorName, BrowseRichTextPalette s) {
    switch (colorName.toLowerCase()) {
      case 'red': return const Color(0xFFEF4444);
      case 'green': return const Color(0xFF22C55E);
      case 'blue': return const Color(0xFF3B82F6);
      case 'yellow': return const Color(0xFFF59E0B);
      case 'orange': return const Color(0xFFF97316);
      case 'purple': return s.primary;
      case 'pink': return s.primary;
      case 'cyan': return const Color(0xFF06B6D4);
      case 'white': return Colors.white;
      case 'black': return Colors.black;
      case 'gray': case 'grey': return const Color(0xFF9CA3AF);
      default: return s.onSurface;
    }
  }

  double _estimateFracWidth(String num, String den, double fontSize) {
    final longer = num.length > den.length ? num.length : den.length;
    return (longer * fontSize * 0.56).clamp(fontSize * 0.9, fontSize * 6);
  }
}

MathBlockParseResult _extractMathBlocks(String raw) {
  final blocks = <String>[];
  final pattern = RegExp(r'\$\$([\s\S]+?)\$\$');
  int i = 0;
  final text = raw.replaceAllMapped(pattern, (m) {
    blocks.add(m.group(1)!.trim());
    return '\u0000MB${i++}\u0000';
  });
  return MathBlockParseResult(textWithMarkers: text, blocks: blocks);
}

class MathBlockParseResult {
  final String textWithMarkers;
  final List<String> blocks;
  const MathBlockParseResult({required this.textWithMarkers, required this.blocks});
}

// ══════════════════════════════════════════════════════════════
// RichAiText — ponto de entrada.
// ══════════════════════════════════════════════════════════════

class RichAiText extends StatelessWidget {
  const RichAiText({
    super.key,
    required this.text,
    this.palette,
    this.bodyTextStyle,
  });

  final String text;
  final BrowseRichTextPalette? palette;
  final TextStyle? bodyTextStyle;

  @override
  Widget build(BuildContext context) {
    final colors = palette ?? BrowseRichTextPalette.fromContext(context);
    final parsed = _parseRichAiVisualBlocks(text);
    if (parsed.blocks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _RichTextBlockParser.parse(
          text,
          colors,
          bodyTextStyle: bodyTextStyle,
        ),
      );
    }

    final children = <Widget>[];
    final markerPattern = RegExp(r'\u0000RW(\d+)\u0000');
    var last = 0;
    for (final match in markerPattern.allMatches(parsed.textWithMarkers)) {
      if (match.start > last) {
        final segment = parsed.textWithMarkers.substring(last, match.start);
        if (segment.trim().isNotEmpty) {
          children.addAll(_RichTextBlockParser.parse(
            segment,
            colors,
            bodyTextStyle: bodyTextStyle,
          ));
        }
      }
      final index = int.tryParse(match.group(1) ?? '') ?? -1;
      if (index >= 0 && index < parsed.blocks.length) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: _buildRichAiVisualBlock(parsed.blocks[index], colors),
        ));
      }
      last = match.end;
    }
    if (last < parsed.textWithMarkers.length) {
      final segment = parsed.textWithMarkers.substring(last);
      if (segment.trim().isNotEmpty) {
        children.addAll(_RichTextBlockParser.parse(
          segment,
          colors,
          bodyTextStyle: bodyTextStyle,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

// Blocos visuais estruturados usados pelo RichText do projeto de referência.
// O parser só transforma JSON válido em widgets; blocos inválidos permanecem
// como código normal, evitando ocultar conteúdo que a IA tenha produzido.
const Set<String> _supportedRichAiBlocks = <String>{
  'widget_market',
  'widget_calendar',
  'widget_map',
  'widget_chart',
  'widget_metric',
  'widget_steps',
  'widget_table',
  'widget_comparison',
  'widget_progress',
  'widget_checklist',
  'widget_timeline',
  'widget_alert',
  'widget_faq',
  'widget_sources',
  'widget_weather',
  'widget_news',
  'widget_product',
  'widget_rating',
  'widget_key_values',
  'widget_bar_chart',
  'widget_image_gallery',
};

class _RichAiVisualBlock {
  const _RichAiVisualBlock({required this.id, required this.json});
  final String id;
  final Map<String, dynamic> json;
}

class _RichAiVisualParseResult {
  const _RichAiVisualParseResult({required this.textWithMarkers, required this.blocks});
  final String textWithMarkers;
  final List<_RichAiVisualBlock> blocks;
}

_RichAiVisualParseResult _parseRichAiVisualBlocks(String raw) {
  final blocks = <_RichAiVisualBlock>[];
  final pattern = RegExp(r'```(widget_[a-z0-9_]+)\s*\n([\s\S]*?)```', multiLine: true);
  final replaced = raw.replaceAllMapped(pattern, (match) {
    final id = match.group(1) ?? '';
    if (!_supportedRichAiBlocks.contains(id)) return match.group(0)!;
    try {
      final decoded = jsonDecode(match.group(2)!.trim());
      if (decoded is! Map) return match.group(0)!;
      final index = blocks.length;
      blocks.add(_RichAiVisualBlock(
        id: id,
        json: Map<String, dynamic>.from(decoded),
      ));
      return '\u0000RW$index\u0000';
    } catch (_) {
      return match.group(0)!;
    }
  });
  return _RichAiVisualParseResult(textWithMarkers: replaced, blocks: blocks);
}

Widget _buildRichAiVisualBlock(
  _RichAiVisualBlock block,
  BrowseRichTextPalette colors,
) {
  switch (block.id) {
    case 'widget_market':
      return _RichAiMarketCard(json: block.json, colors: colors);
    case 'widget_calendar':
      return _RichAiCalendarCard(json: block.json, colors: colors);
    case 'widget_map':
      return _RichAiMapCard(json: block.json, colors: colors);
    case 'widget_chart':
      return _RichAiChartCard(json: block.json, colors: colors);
    case 'widget_metric':
      return _RichAiMetricCard(json: block.json, colors: colors);
    case 'widget_steps':
      return _RichAiStepsCard(json: block.json, colors: colors);
    case 'widget_table':
      return buildAiTableFromWidgetJson(block.json, colors);
    case 'widget_comparison':
      return _RichAiComparisonCard(json: block.json, colors: colors);
    case 'widget_progress':
      return _RichAiProgressCard(json: block.json, colors: colors);
    case 'widget_checklist':
      return _RichAiChecklistCard(json: block.json, colors: colors);
    case 'widget_timeline':
      return _RichAiTimelineCard(json: block.json, colors: colors);
    case 'widget_alert':
      return _RichAiAlertCard(json: block.json, colors: colors);
    case 'widget_faq':
      return _RichAiFaqCard(json: block.json, colors: colors);
    case 'widget_sources':
      return _RichAiSourcesCard(json: block.json, colors: colors);
    case 'widget_weather':
      return _RichAiWeatherCard(json: block.json, colors: colors);
    case 'widget_news':
      return _RichAiNewsCard(json: block.json, colors: colors);
    case 'widget_product':
      return _RichAiProductCard(json: block.json, colors: colors);
    case 'widget_rating':
      return _RichAiRatingCard(json: block.json, colors: colors);
    case 'widget_key_values':
      return _RichAiKeyValuesCard(json: block.json, colors: colors);
    case 'widget_bar_chart':
      return _RichAiBarChartCard(json: block.json, colors: colors);
    case 'widget_image_gallery':
      return _RichAiImageGalleryCard(json: block.json, colors: colors);
    default:
      return const SizedBox.shrink();
  }
}

class _RichAiCard extends StatelessWidget {
  const _RichAiCard({required this.colors, required this.child});
  final BrowseRichTextPalette colors;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.hover,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outline.withOpacity(.42), width: .7),
        ),
        child: child,
      );
}

class _RichAiCardHeading extends StatelessWidget {
  const _RichAiCardHeading({required this.icon, required this.title, required this.colors, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  final BrowseRichTextPalette colors;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: colors.primary, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
                if (subtitle != null && subtitle!.trim().isNotEmpty)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      );
}

String _richValue(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

double? _richNumber(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.').replaceAll('%', '').trim());
  return null;
}

String _richDateLabel(dynamic raw) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '');
  if (parsed == null) return _richValue(raw, fallback: 'Data não indicada');
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}';
}

class _RichAiMarketCard extends StatelessWidget {
  const _RichAiMarketCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;

  @override
  Widget build(BuildContext context) {
    final name = _richValue(json['name'], fallback: _richValue(json['symbol'], fallback: 'Mercado'));
    final symbol = _richValue(json['symbol']);
    final price = json['price'] ?? json['currentPrice'] ?? json['current_price'];
    final currency = _richValue(json['currency'], fallback: '');
    final change = _richNumber(json['changePercent'] ?? json['change_percent'] ?? json['change']);
    final seriesRaw = json['series'] ?? json['values'] ?? json['history'];
    final series = seriesRaw is List
        ? seriesRaw.map(_richNumber).whereType<double>().toList(growable: false)
        : const <double>[];
    final positive = (change ?? 0) >= 0;
    final semantic = positive ? const Color(0xFF21885B) : const Color(0xFFC84B4B);
    return _RichAiCard(
      colors: colors,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _RichAiCardHeading(icon: Icons.show_chart_rounded, title: name, subtitle: symbol.isEmpty ? 'Mercado' : symbol, colors: colors),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Text(
              price == null ? 'Cotação não incluída' : '$currency${_richValue(price)}',
              style: TextStyle(color: colors.onSurface, fontSize: price == null ? 15 : 24, fontWeight: FontWeight.w800),
            ),
          ),
          if (change != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: semantic.withOpacity(.12), borderRadius: BorderRadius.circular(999)),
              child: Text('${positive ? '+' : ''}${change.toStringAsFixed(2)}%',
                  style: TextStyle(color: semantic, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ]),
        if (series.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(height: 72, width: double.infinity, child: CustomPaint(painter: _RichAiLinePainter(values: series, color: colors.primary, gridColor: colors.outline.withOpacity(.2)))),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 8, children: [
          if (json['high24h'] != null || json['high_24h'] != null)
            _RichAiTinyValue(label: 'Máximo 24h', value: _richValue(json['high24h'] ?? json['high_24h']), colors: colors),
          if (json['low24h'] != null || json['low_24h'] != null)
            _RichAiTinyValue(label: 'Mínimo 24h', value: _richValue(json['low24h'] ?? json['low_24h']), colors: colors),
          if (json['volume24h'] != null || json['volume_24h'] != null)
            _RichAiTinyValue(label: 'Volume 24h', value: _richValue(json['volume24h'] ?? json['volume_24h']), colors: colors),
        ]),
      ]),
    );
  }
}

class _RichAiTinyValue extends StatelessWidget {
  const _RichAiTinyValue({required this.label, required this.value, required this.colors});
  final String label;
  final String value;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10.5)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(color: colors.onSurface, fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}

class _RichAiCalendarCard extends StatelessWidget {
  const _RichAiCalendarCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;

  @override
  Widget build(BuildContext context) {
    final date = json['isoDate'] ?? json['date'] ?? json['start'];
    final eventsRaw = json['events'] ?? json['items'];
    final events = eventsRaw is List ? eventsRaw.whereType<Map>().toList(growable: false) : const <Map>[];
    final dateTime = DateTime.tryParse(date?.toString() ?? '');
    return _RichAiCard(
      colors: colors,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _RichAiCardHeading(icon: Icons.calendar_month_rounded, title: _richValue(json['title'], fallback: 'Calendário'), subtitle: _richValue(json['humanLabel']), colors: colors),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: colors.primary.withOpacity(.12), borderRadius: BorderRadius.circular(13)),
            child: Column(children: [
              Text(dateTime == null ? '—' : dateTime.day.toString(), style: TextStyle(color: colors.primary, fontSize: 23, fontWeight: FontWeight.w800)),
              Text(dateTime == null ? 'DATA' : dateTime.month.toString().padLeft(2, '0'), style: TextStyle(color: colors.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .8)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_richDateLabel(date), style: TextStyle(color: colors.onSurface, fontSize: 15, fontWeight: FontWeight.w700))),
        ]),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final event in events.take(8))
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6, right: 9), decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_richValue(event['title'] ?? event['name'], fallback: 'Evento'), style: TextStyle(color: colors.onSurface, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  if (_richValue(event['time'] ?? event['description']).isNotEmpty)
                    Text(_richValue(event['time'] ?? event['description']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5)),
                ])),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _RichAiMapCard extends StatelessWidget {
  const _RichAiMapCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;

  @override
  Widget build(BuildContext context) {
    final lat = _richNumber(json['lat'] ?? json['latitude']);
    final lng = _richNumber(json['lng'] ?? json['lon'] ?? json['longitude']);
    final title = _richValue(json['name'] ?? json['title'], fallback: 'Localização');
    return _RichAiCard(
      colors: colors,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _RichAiCardHeading(icon: Icons.location_on_rounded, title: title, subtitle: _richValue(json['address'] ?? json['formattedAddress']), colors: colors),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            height: 116,
            width: double.infinity,
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(child: CustomPaint(painter: _RichAiMapPatternPainter(line: colors.outline.withOpacity(.3), fill: colors.pageBackground))),
              Container(width: 38, height: 38, decoration: BoxDecoration(color: colors.primary.withOpacity(.13), shape: BoxShape.circle)),
              Icon(Icons.location_on_rounded, size: 32, color: colors.primary),
            ]),
          ),
        ),
        if (lat != null && lng != null) ...[
          const SizedBox(height: 9),
          Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5)),
        ],
        if (_richValue(json['description']).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_richValue(json['description']), style: TextStyle(color: colors.onSurface, fontSize: 12.5, height: 1.4)),
        ],
      ]),
    );
  }
}

class _RichAiChartCard extends StatelessWidget {
  const _RichAiChartCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final raw = json['values'] ?? json['series'] ?? json['data'];
    final values = raw is List
        ? raw.map((item) => item is Map ? _richNumber(item['value'] ?? item['y']) : _richNumber(item)).whereType<double>().toList(growable: false)
        : const <double>[];
    final labels = (json['labels'] is List) ? (json['labels'] as List).map((e) => e.toString()).toList(growable: false) : const <String>[];
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.analytics_rounded, title: _richValue(json['title'], fallback: 'Gráfico'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 12),
      if (values.length >= 2)
        SizedBox(height: 140, width: double.infinity, child: CustomPaint(painter: _RichAiLinePainter(values: values, color: colors.primary, gridColor: colors.outline.withOpacity(.2)))),
      if (values.length < 2)
        Text('Não há pontos suficientes para desenhar o gráfico.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
      if (labels.isNotEmpty) ...[
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(labels.first, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10)),
          Text(labels.last, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10)),
        ]),
      ],
    ]));
  }
}

class _RichAiMetricCard extends StatelessWidget {
  const _RichAiMetricCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final raw = json['metrics'] ?? json['items'];
    final metrics = raw is List ? raw.whereType<Map>().take(8).toList(growable: false) : const <Map>[];
    final entries = metrics.isEmpty ? <Map>[json] : metrics;
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.dashboard_rounded, title: _richValue(json['title'], fallback: 'Indicadores'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 12),
      Wrap(spacing: 9, runSpacing: 9, children: entries.map((item) {
        final label = _richValue(item['label'] ?? item['name'], fallback: 'Valor');
        final value = _richValue(item['value'], fallback: '—');
        final unit = _richValue(item['unit']);
        return Container(
          constraints: const BoxConstraints(minWidth: 108, maxWidth: 210),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(color: colors.pageBackground, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10.5)),
            const SizedBox(height: 4),
            Text('$value${unit.isEmpty ? '' : ' $unit'}', style: TextStyle(color: colors.onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        );
      }).toList(growable: false)),
    ]));
  }
}

class _RichAiStepsCard extends StatelessWidget {
  const _RichAiStepsCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final raw = json['steps'] ?? json['items'];
    final steps = raw is List ? raw.whereType<Map>().take(12).toList(growable: false) : const <Map>[];
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.format_list_numbered_rounded, title: _richValue(json['title'], fallback: 'Etapas'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 10),
      for (var i = 0; i < steps.length; i++)
        Padding(padding: const EdgeInsets.only(top: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 25, height: 25, alignment: Alignment.center, decoration: BoxDecoration(color: colors.primary.withOpacity(.13), shape: BoxShape.circle), child: Text('${i + 1}', style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.w800))),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_richValue(steps[i]['title'] ?? steps[i]['name'], fallback: 'Etapa ${i + 1}'), style: TextStyle(color: colors.onSurface, fontSize: 12.5, fontWeight: FontWeight.w700)),
            if (_richValue(steps[i]['description'] ?? steps[i]['detail']).isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(_richValue(steps[i]['description'] ?? steps[i]['detail']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, height: 1.4))),
          ])),
        ])),
      if (steps.isEmpty) Text('Nenhuma etapa foi fornecida.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    ]));
  }
}



List<Map<String, dynamic>> _richMapList(dynamic raw, {int limit = 16}) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .take(limit)
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _richStringList(dynamic raw, {int limit = 12}) {
  if (raw is! List) return const <String>[];
  return raw
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .take(limit)
      .toList(growable: false);
}

bool _richBool(dynamic raw) {
  if (raw is bool) return raw;
  final value = raw?.toString().toLowerCase().trim();
  return value == 'true' || value == '1' || value == 'yes' || value == 'done' || value == 'completed';
}

String _richSafeUrl(dynamic raw) {
  final value = _richValue(raw);
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) return '';
  return uri.toString();
}

class _RichAiComparisonCard extends StatelessWidget {
  const _RichAiComparisonCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;

  @override
  Widget build(BuildContext context) {
    final items = _richMapList(json['items'] ?? json['options'] ?? json['products'], limit: 6);
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.compare_arrows_rounded, title: _richValue(json['title'], fallback: 'Comparação'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 12),
      if (items.isEmpty)
        Text('Não foram fornecidos elementos suficientes para comparar.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5)),
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) Divider(height: 18, color: colors.outline.withOpacity(.25)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: colors.primary.withOpacity(.12), borderRadius: BorderRadius.circular(9)), child: Text('${i + 1}', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_richValue(items[i]['name'] ?? items[i]['title'], fallback: 'Opção ${i + 1}'), style: TextStyle(color: colors.onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
            if (_richValue(items[i]['value'] ?? items[i]['summary'] ?? items[i]['description']).isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 3), child: Text(_richValue(items[i]['value'] ?? items[i]['summary'] ?? items[i]['description']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, height: 1.4))),
            ..._richStringList(items[i]['pros'], limit: 4).map((value) => _RichAiComparisonPoint(text: value, positive: true, colors: colors)),
            ..._richStringList(items[i]['cons'], limit: 4).map((value) => _RichAiComparisonPoint(text: value, positive: false, colors: colors)),
            if (items[i]['attributes'] is Map)
              ...Map<String, dynamic>.from(items[i]['attributes'] as Map).entries.take(8).map((entry) => Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(entry.key, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5))),
                const SizedBox(width: 8),
                Flexible(child: Text(entry.value?.toString() ?? '—', textAlign: TextAlign.end, style: TextStyle(color: colors.onSurface, fontSize: 11.5, fontWeight: FontWeight.w600))),
              ]))),
          ])),
        ]),
      ],
      if (_richValue(json['verdict']).isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(width: double.infinity, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: colors.primary.withOpacity(.08), borderRadius: BorderRadius.circular(12)), child: Text(_richValue(json['verdict']), style: TextStyle(color: colors.onSurface, fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w600))),
      ],
    ]));
  }
}

class _RichAiComparisonPoint extends StatelessWidget {
  const _RichAiComparisonPoint({required this.text, required this.positive, required this.colors});
  final String text;
  final bool positive;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(positive ? Icons.check_circle_outline_rounded : Icons.remove_circle_outline_rounded, size: 14, color: positive ? const Color(0xFF21885B) : colors.onSurfaceVariant),
    const SizedBox(width: 6),
    Expanded(child: Text(text, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, height: 1.35))),
  ]));
}

class _RichAiProgressCard extends StatelessWidget {
  const _RichAiProgressCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final items = _richMapList(json['items'] ?? json['metrics'], limit: 12);
    final source = items.isEmpty ? <Map<String, dynamic>>[json] : items;
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.track_changes_rounded, title: _richValue(json['title'], fallback: 'Progresso'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 13),
      for (var i = 0; i < source.length; i++) ...[
        if (i > 0) const SizedBox(height: 13),
        Builder(builder: (context) {
          final item = source[i];
          final rawValue = _richNumber(item['value'] ?? item['progress'] ?? item['percent']);
          final fraction = rawValue == null ? null : (rawValue > 1 ? rawValue / 100 : rawValue).clamp(0.0, 1.0).toDouble();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(_richValue(item['label'] ?? item['name'], fallback: 'Progresso'), style: TextStyle(color: colors.onSurface, fontSize: 12.5, fontWeight: FontWeight.w600))), if (rawValue != null) Text('${(rawValue <= 1 ? rawValue * 100 : rawValue).toStringAsFixed(rawValue % 1 == 0 ? 0 : 1)}%', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, fontWeight: FontWeight.w700))]),
            if (fraction != null) ...[
              const SizedBox(height: 7),
              ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: fraction, minHeight: 7, backgroundColor: colors.outline.withOpacity(.16), valueColor: AlwaysStoppedAnimation<Color>(colors.primary))),
            ],
            if (_richValue(item['description'] ?? item['detail']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text(_richValue(item['description'] ?? item['detail']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, height: 1.35))),
          ]);
        }),
      ],
    ]));
  }
}

class _RichAiChecklistCard extends StatelessWidget {
  const _RichAiChecklistCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final items = _richMapList(json['items'] ?? json['tasks'], limit: 24);
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.checklist_rounded, title: _richValue(json['title'], fallback: 'Lista de verificação'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 8),
      for (final item in items)
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_richBool(item['done'] ?? item['completed'] ?? item['checked']) ? Icons.check_circle_rounded : Icons.circle_outlined, color: _richBool(item['done'] ?? item['completed'] ?? item['checked']) ? colors.primary : colors.onSurfaceVariant, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_richValue(item['title'] ?? item['label'] ?? item['task'], fallback: 'Item'), style: TextStyle(color: colors.onSurface, fontSize: 12.5, fontWeight: FontWeight.w600)),
            if (_richValue(item['description'] ?? item['detail']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(_richValue(item['description'] ?? item['detail']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, height: 1.35))),
          ])),
        ])),
      if (items.isEmpty) Text('Nenhum item foi indicado.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    ]));
  }
}

class _RichAiTimelineCard extends StatelessWidget {
  const _RichAiTimelineCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final items = _richMapList(json['items'] ?? json['events'], limit: 18);
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.timeline_rounded, title: _richValue(json['title'], fallback: 'Cronologia'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 12),
      for (var i = 0; i < items.length; i++)
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 23, child: Column(children: [Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle)), if (i < items.length - 1) Expanded(child: Container(width: 1.5, margin: const EdgeInsets.symmetric(vertical: 3), color: colors.outline.withOpacity(.45)))])),
          const SizedBox(width: 7),
          Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_richValue(items[i]['date'] ?? items[i]['time'] ?? items[i]['period']), style: TextStyle(color: colors.primary, fontSize: 10.5, fontWeight: FontWeight.w700)),
            Text(_richValue(items[i]['title'] ?? items[i]['name'], fallback: 'Evento ${i + 1}'), style: TextStyle(color: colors.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
            if (_richValue(items[i]['description'] ?? items[i]['detail']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(_richValue(items[i]['description'] ?? items[i]['detail']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, height: 1.4))),
          ]))),
        ]),
      if (items.isEmpty) Text('Não há eventos para apresentar.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    ]));
  }
}

class _RichAiAlertCard extends StatelessWidget {
  const _RichAiAlertCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final kind = _richValue(json['type'] ?? json['severity'], fallback: 'info').toLowerCase();
    final semantic = kind.contains('error') || kind.contains('danger') || kind.contains('critical') ? const Color(0xFFC84B4B) : kind.contains('warn') ? const Color(0xFFD18A24) : kind.contains('success') ? const Color(0xFF21885B) : colors.primary;
    final icon = kind.contains('error') || kind.contains('danger') || kind.contains('critical') ? Icons.error_outline_rounded : kind.contains('warn') ? Icons.warning_amber_rounded : kind.contains('success') ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded;
    return Container(width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: semantic.withOpacity(.09), border: Border.all(color: semantic.withOpacity(.28)), borderRadius: BorderRadius.circular(16)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: semantic, size: 21), const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_richValue(json['title'], fallback: 'Informação importante'), style: TextStyle(color: colors.onSurface, fontSize: 13.5, fontWeight: FontWeight.w800)),
        if (_richValue(json['message'] ?? json['description'] ?? json['text']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_richValue(json['message'] ?? json['description'] ?? json['text']), style: TextStyle(color: colors.onSurface, fontSize: 12.5, height: 1.45))),
      ])),
    ]));
  }
}

class _RichAiFaqCard extends StatelessWidget {
  const _RichAiFaqCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final items = _richMapList(json['items'] ?? json['questions'], limit: 16);
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.help_outline_rounded, title: _richValue(json['title'], fallback: 'Perguntas frequentes'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 5),
      for (var i = 0; i < items.length; i++)
        Theme(data: Theme.of(context).copyWith(dividerColor: Colors.transparent), child: ExpansionTile(
          key: ValueKey<String>('rich-faq-$i-${_richValue(items[i]['question'])}'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          iconColor: colors.primary,
          collapsedIconColor: colors.onSurfaceVariant,
          title: Text(_richValue(items[i]['question'] ?? items[i]['title'], fallback: 'Pergunta'), style: TextStyle(color: colors.onSurface, fontSize: 12.5, fontWeight: FontWeight.w600)),
          children: [Align(alignment: Alignment.centerLeft, child: Text(_richValue(items[i]['answer'] ?? items[i]['content'], fallback: 'Resposta não fornecida.'), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, height: 1.45)))],
        )),
      if (items.isEmpty) Text('Não foram fornecidas perguntas.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    ]));
  }
}

class _RichAiSourcesCard extends StatelessWidget {
  const _RichAiSourcesCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final items = _richMapList(json['items'] ?? json['sources'] ?? json['references'], limit: 20);
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.link_rounded, title: _richValue(json['title'], fallback: 'Fontes e referências'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 8),
      for (var i = 0; i < items.length; i++)
        Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 23, height: 23, alignment: Alignment.center, decoration: BoxDecoration(color: colors.primary.withOpacity(.1), shape: BoxShape.circle), child: Text('${i + 1}', style: TextStyle(color: colors.primary, fontSize: 10, fontWeight: FontWeight.w800))),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_richValue(items[i]['title'] ?? items[i]['name'], fallback: 'Fonte ${i + 1}'), style: TextStyle(color: colors.onSurface, fontSize: 12.5, fontWeight: FontWeight.w700)),
            if (_richValue(items[i]['publisher'] ?? items[i]['source']).isNotEmpty) Text(_richValue(items[i]['publisher'] ?? items[i]['source']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10.8)),
            if (_richValue(items[i]['date'] ?? items[i]['publishedAt']).isNotEmpty) Text(_richValue(items[i]['date'] ?? items[i]['publishedAt']), style: TextStyle(color: colors.onSurfaceVariant.withOpacity(.85), fontSize: 10)),
            if (_richValue(items[i]['snippet'] ?? items[i]['description']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(_richValue(items[i]['snippet'] ?? items[i]['description']), style: TextStyle(color: colors.onSurface, fontSize: 11.5, height: 1.35))),
            if (_richSafeUrl(items[i]['url'] ?? items[i]['link']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: SelectableText(_richSafeUrl(items[i]['url'] ?? items[i]['link']), style: TextStyle(color: colors.primary, fontSize: 10.5, decoration: TextDecoration.underline))),
          ])),
        ])),
      if (items.isEmpty) Text('O servidor não forneceu referências verificáveis.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    ]));
  }
}

class _RichAiWeatherCard extends StatelessWidget {
  const _RichAiWeatherCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final temp = _richValue(json['temperature'] ?? json['temp'], fallback: '—');
    final condition = _richValue(json['condition'] ?? json['description'], fallback: 'Condição não indicada');
    final forecast = _richMapList(json['forecast'] ?? json['days'], limit: 7);
    final lower = condition.toLowerCase();
    final weatherIcon = lower.contains('rain') || lower.contains('chuva') ? Icons.water_drop_rounded : lower.contains('storm') || lower.contains('trovoada') ? Icons.thunderstorm : lower.contains('cloud') || lower.contains('nublado') ? Icons.cloud_rounded : lower.contains('snow') || lower.contains('neve') ? Icons.ac_unit_rounded : Icons.wb_sunny_rounded;
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.location_on_outlined, title: _richValue(json['city'] ?? json['location'], fallback: 'Meteorologia'), subtitle: _richValue(json['updatedAt'] ?? json['updated']), colors: colors),
      const SizedBox(height: 12),
      Row(children: [Icon(weatherIcon, color: colors.primary, size: 42), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(temp, style: TextStyle(color: colors.onSurface, fontSize: 27, fontWeight: FontWeight.w800)), Text(condition, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12))]))]),
      const SizedBox(height: 12),
      Wrap(spacing: 18, runSpacing: 7, children: [
        if (json['high'] != null || json['highTemp'] != null) _RichAiTinyValue(label: 'Máxima', value: _richValue(json['high'] ?? json['highTemp']), colors: colors),
        if (json['low'] != null || json['lowTemp'] != null) _RichAiTinyValue(label: 'Mínima', value: _richValue(json['low'] ?? json['lowTemp']), colors: colors),
        if (json['humidity'] != null) _RichAiTinyValue(label: 'Humidade', value: _richValue(json['humidity']), colors: colors),
        if (json['wind'] != null) _RichAiTinyValue(label: 'Vento', value: _richValue(json['wind']), colors: colors),
      ]),
      if (forecast.isNotEmpty) ...[
        Divider(height: 20, color: colors.outline.withOpacity(.25)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: forecast.map((day) {
              return Container(
                width: 78,
                margin: const EdgeInsets.only(right: 7),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colors.pageBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text(
                    _richValue(day['day'] ?? day['date'], fallback: '—'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                  ),
                  const SizedBox(height: 5),
                  Icon(Icons.wb_cloudy_outlined, color: colors.primary, size: 19),
                  const SizedBox(height: 4),
                  Text(
                    _richValue(day['temperature'] ?? day['temp'], fallback: '—'),
                    style: TextStyle(color: colors.onSurface, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ]),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    ]));
  }
}

class _RichAiNewsCard extends StatelessWidget {
  const _RichAiNewsCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final items = _richMapList(json['items'] ?? json['articles'], limit: 10);
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.article_outlined, title: _richValue(json['title'], fallback: 'Notícias'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 6),
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) Divider(height: 18, color: colors.outline.withOpacity(.25)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_richSafeUrl(items[i]['image'] ?? items[i]['imageUrl']).isNotEmpty) ...[
            ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.network(_richSafeUrl(items[i]['image'] ?? items[i]['imageUrl']), width: 76, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 76, height: 70, color: colors.pageBackground, alignment: Alignment.center, child: Icon(Icons.image_not_supported_outlined, color: colors.onSurfaceVariant, size: 18)))),
            const SizedBox(width: 10),
          ],
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_richValue(items[i]['title'] ?? items[i]['headline'], fallback: 'Notícia ${i + 1}'), style: TextStyle(color: colors.onSurface, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35)),
            if (_richValue(items[i]['publisher'] ?? items[i]['source']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(_richValue(items[i]['publisher'] ?? items[i]['source']), style: TextStyle(color: colors.primary, fontSize: 10.5, fontWeight: FontWeight.w600))),
            if (_richValue(items[i]['date'] ?? items[i]['publishedAt']).isNotEmpty) Text(_richValue(items[i]['date'] ?? items[i]['publishedAt']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10)),
            if (_richValue(items[i]['summary'] ?? items[i]['description']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_richValue(items[i]['summary'] ?? items[i]['description']), maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, height: 1.35))),
          ])),
        ]),
      ],
      if (items.isEmpty) Text('Não há notícias disponíveis para apresentar.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    ]));
  }
}

class _RichAiProductCard extends StatelessWidget {
  const _RichAiProductCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final products = _richMapList(json['items'] ?? json['products'], limit: 8);
    final list = products.isEmpty ? <Map<String, dynamic>>[json] : products;
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.shopping_bag_outlined, title: _richValue(json['title'], fallback: 'Produtos'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 10),
      for (var i = 0; i < list.length; i++) ...[
        if (i > 0) Divider(height: 18, color: colors.outline.withOpacity(.25)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_richSafeUrl(list[i]['image'] ?? list[i]['imageUrl']).isNotEmpty) ...[
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_richSafeUrl(list[i]['image'] ?? list[i]['imageUrl']), width: 82, height: 82, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 82, height: 82, color: colors.pageBackground, alignment: Alignment.center, child: Icon(Icons.image_outlined, color: colors.onSurfaceVariant)))),
            const SizedBox(width: 11),
          ],
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_richValue(list[i]['name'] ?? list[i]['title'], fallback: 'Item ${i + 1}'), style: TextStyle(color: colors.onSurface, fontSize: 13.5, fontWeight: FontWeight.w700)),
            if (_richValue(list[i]['brand']).isNotEmpty) Text(_richValue(list[i]['brand']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10.5)),
            if (_richValue(list[i]['price']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_richValue(list[i]['price']), style: TextStyle(color: colors.primary, fontSize: 15, fontWeight: FontWeight.w800))),
            if (_richValue(list[i]['description']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_richValue(list[i]['description']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, height: 1.35))),
            if (_richStringList(list[i]['features'], limit: 3).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_richStringList(list[i]['features'], limit: 3).join(' • '), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10.5, height: 1.35))),
          ])),
        ]),
      ],
      if (_richValue(json['note']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 9), child: Text(_richValue(json['note']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10.5))),
    ]));
  }
}

class _RichAiRatingCard extends StatelessWidget {
  const _RichAiRatingCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final score = _richNumber(json['score'] ?? json['rating']);
    final maximum = _richNumber(json['maxScore'] ?? json['max_score']) ?? 5;
    final ratio = score == null || maximum <= 0 ? null : (score / maximum).clamp(0.0, 1.0).toDouble();
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.star_outline_rounded, title: _richValue(json['title'], fallback: 'Avaliação'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (score != null) Text(score.toStringAsFixed(1), style: TextStyle(color: colors.onSurface, fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (ratio != null) Row(children: List.generate(5, (index) => Icon(index + 1 <= (ratio * 5).round() ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: colors.primary))),
          if (_richValue(json['reviewCount'] ?? json['reviews']).isNotEmpty) Text('${_richValue(json['reviewCount'] ?? json['reviews'])} avaliações', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10.5)),
        ])),
      ]),
      if (_richValue(json['summary']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_richValue(json['summary']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, height: 1.4))),
    ]));
  }
}

class _RichAiKeyValuesCard extends StatelessWidget {
  const _RichAiKeyValuesCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final items = _richMapList(json['items'] ?? json['values'], limit: 24);
    final entries = items.isEmpty && json['values'] is Map ? Map<String, dynamic>.from(json['values'] as Map).entries.map((e) => <String, dynamic>{'label': e.key, 'value': e.value}).toList() : items;
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.list_alt_rounded, title: _richValue(json['title'], fallback: 'Dados principais'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 9),
      for (var i = 0; i < entries.length; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(_richValue(entries[i]['label'] ?? entries[i]['name'], fallback: 'Campo'), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12))),
        const SizedBox(width: 12),
        Flexible(child: Text(_richValue(entries[i]['value'], fallback: '—'), textAlign: TextAlign.end, style: TextStyle(color: colors.onSurface, fontSize: 12, fontWeight: FontWeight.w700))),
      ])),
      if (entries.isEmpty) Text('Não foram fornecidos dados.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    ]));
  }
}

class _RichAiBarChartCard extends StatelessWidget {
  const _RichAiBarChartCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final items = _richMapList(json['items'] ?? json['data'], limit: 14);
    final maxValue = items.map((item) => _richNumber(item['value']) ?? 0).fold<double>(0, (a, b) => a > b ? a : b);
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.bar_chart_rounded, title: _richValue(json['title'], fallback: 'Gráfico de barras'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 12),
      for (final item in items) Builder(builder: (context) {
        final value = _richNumber(item['value']) ?? 0;
        final fraction = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();
        return Padding(padding: const EdgeInsets.only(bottom: 11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(_richValue(item['label'] ?? item['name'], fallback: 'Item'), style: TextStyle(color: colors.onSurface, fontSize: 11.5, fontWeight: FontWeight.w600))), Text(_richValue(item['display'] ?? item['value']), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11))]),
          const SizedBox(height: 5),
          ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: fraction, minHeight: 8, backgroundColor: colors.outline.withOpacity(.15), valueColor: AlwaysStoppedAnimation<Color>(colors.primary))),
        ]));
      }),
      if (items.isEmpty) Text('Não há valores para representar.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    ]));
  }
}

class _RichAiImageGalleryCard extends StatelessWidget {
  const _RichAiImageGalleryCard({required this.json, required this.colors});
  final Map<String, dynamic> json;
  final BrowseRichTextPalette colors;
  @override
  Widget build(BuildContext context) {
    final items = _richMapList(json['items'] ?? json['images'], limit: 12);
    return _RichAiCard(colors: colors, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RichAiCardHeading(icon: Icons.photo_library_outlined, title: _richValue(json['title'], fallback: 'Imagens'), subtitle: _richValue(json['subtitle']), colors: colors),
      const SizedBox(height: 10),
      SizedBox(
        height: 142,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 9),
          itemBuilder: (context, index) {
            final url = _richSafeUrl(items[index]['url'] ?? items[index]['image']);
            return SizedBox(
              width: 190,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: url.isEmpty
                        ? Container(
                            width: double.infinity,
                            color: colors.pageBackground,
                            alignment: Alignment.center,
                            child: Icon(Icons.image_not_supported_outlined, color: colors.onSurfaceVariant),
                          )
                        : Image.network(
                            url,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: double.infinity,
                              color: colors.pageBackground,
                              alignment: Alignment.center,
                              child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _richValue(items[index]['caption'] ?? items[index]['title'], fallback: 'Imagem ${index + 1}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurface, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ]),
            );
          },
        ),
      ),
      if (items.isEmpty) Text('Não há imagens para apresentar.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    ]));
  }
}

class _RichAiLinePainter extends CustomPainter {
  const _RichAiLinePainter({required this.values, required this.color, required this.gridColor});
  final List<double> values;
  final Color color;
  final Color gridColor;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final grid = Paint()..color = gridColor..strokeWidth = .7;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.000001 ? 1.0 : maxValue - minValue;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minValue) / range) * (size.height * .82) - size.height * .09;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    final line = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);
  }
  @override
  bool shouldRepaint(covariant _RichAiLinePainter oldDelegate) => oldDelegate.values != values || oldDelegate.color != color || oldDelegate.gridColor != gridColor;
}

class _RichAiMapPatternPainter extends CustomPainter {
  const _RichAiMapPatternPainter({required this.line, required this.fill});
  final Color line;
  final Color fill;
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = fill;
    canvas.drawRect(Offset.zero & size, bg);
    final road = Paint()..color = line..strokeWidth = 7..strokeCap = StrokeCap.round;
    final thin = Paint()..color = line.withOpacity(.65)..strokeWidth = 2;
    final path1 = Path()..moveTo(-10, size.height * .75)..cubicTo(size.width * .18, size.height * .62, size.width * .3, size.height * .2, size.width * .58, size.height * .28)..cubicTo(size.width * .78, size.height * .34, size.width * .83, size.height * .8, size.width + 10, size.height * .62);
    canvas.drawPath(path1, road);
    final path2 = Path()..moveTo(size.width * .16, -10)..cubicTo(size.width * .32, size.height * .18, size.width * .38, size.height * .56, size.width * .52, size.height + 10);
    canvas.drawPath(path2, road);
    for (var i = 0; i < 5; i++) {
      final y = size.height * (i + 1) / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width * .2, y - 6), thin);
    }
  }
  @override
  bool shouldRepaint(covariant _RichAiMapPatternPainter oldDelegate) => oldDelegate.line != line || oldDelegate.fill != fill;
}

class _RichTextBlockParser {
  static List<Widget> parse(String raw, BrowseRichTextPalette s, {TextStyle? bodyTextStyle}) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final mathExtract = _extractMathBlocks(normalized);
    if (mathExtract.blocks.isEmpty) {
      return _parseStructural(normalized, s, bodyTextStyle: bodyTextStyle);
    }

    final markerRe = RegExp(r'\u0000MB(\d+)\u0000');
    final widgets = <Widget>[];
    int last = 0;
    for (final m in markerRe.allMatches(mathExtract.textWithMarkers)) {
      if (m.start > last) {
        final segment = mathExtract.textWithMarkers.substring(last, m.start);
        if (segment.trim().isNotEmpty) {
          widgets.addAll(_parseStructural(segment, s, bodyTextStyle: bodyTextStyle));
        }
      }
      final idx = int.parse(m.group(1)!);
      if (idx < mathExtract.blocks.length) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: MathInline(expression: mathExtract.blocks[idx], s: s, block: true),
        ));
      }
      last = m.end;
    }
    if (last < mathExtract.textWithMarkers.length) {
      final segment = mathExtract.textWithMarkers.substring(last);
      if (segment.trim().isNotEmpty) {
        widgets.addAll(_parseStructural(segment, s, bodyTextStyle: bodyTextStyle));
      }
    }
    return widgets;
  }

  static List<Widget> _parseStructural(String raw, BrowseRichTextPalette s, {TextStyle? bodyTextStyle}) {
    final lines = raw.split('\n');
    final widgets = <Widget>[];
    int i = 0;
    List<List<String>>? tableRows;
    List<TextAlign>? tableAlignments;

    void flushTable() {
      if (tableRows != null && tableRows!.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Container(
            color: s.pageBackground,
            child: _AiTable(
              rows: tableRows!,
              s: s,
              alignments: tableAlignments,
            ),
          ),
        ));
      }
      tableRows = null;
      tableAlignments = null;
    }

    bool isFence(String value) => RegExp(r'^\s*(```+|~~~+)').hasMatch(value);

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        flushTable();
        if (widgets.isNotEmpty && widgets.last is! SizedBox) {
          widgets.add(const SizedBox(height: 5));
        }
        i++;
        continue;
      }

      if (RegExp(r'^<details>\s*$').hasMatch(trimmed) ||
          trimmed.startsWith('<details>')) {
        flushTable();
        final detailLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('</details>')) {
          detailLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++;
        widgets.add(_buildDetailsBlock(detailLines.join('\n'), s, bodyTextStyle: bodyTextStyle));
        continue;
      }

      final headerMatch = RegExp(r'^\s*(#{1,6})\s+(.*?)(?:\s+#+)?$').firstMatch(line);
      if (headerMatch != null) {
        flushTable();
        final level = headerMatch.group(1)!.length;
        final content = headerMatch.group(2)!.trim();
        widgets.add(Padding(
          padding: EdgeInsets.only(
            top: widgets.isEmpty ? 0 : (level <= 2 ? 13 : 9),
            bottom: level <= 2 ? 7 : 5,
          ),
          child: _formattedText(
            content,
            s,
            fontSize: switch (level) {
              1 => 25,
              2 => 22,
              3 => 20,
              4 => 18.5,
              5 => 17.5,
              _ => 17,
            },
            fontWeight: FontWeight.w700,
            bodyTextStyle: bodyTextStyle,
          ),
        ));
        i++;
        continue;
      }

      if (i + 1 < lines.length && trimmed.isNotEmpty) {
        final next = lines[i + 1].trim();
        final isH1 = RegExp(r'^={3,}$').hasMatch(next);
        final isH2 = RegExp(r'^-{3,}$').hasMatch(next);
        if ((isH1 || isH2) &&
            !trimmed.startsWith('-') &&
            !trimmed.startsWith('*') &&
            !trimmed.startsWith('+') &&
            !trimmed.startsWith('>')) {
          flushTable();
          widgets.add(Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 12, bottom: 6),
            child: _formattedText(
              trimmed,
              s,
              fontSize: isH1 ? 24 : 20,
              fontWeight: FontWeight.w700,
              bodyTextStyle: bodyTextStyle,
            ),
          ));
          i += 2;
          continue;
        }
      }

      if (RegExp(r'^\s*([-*_])(?:\s*\1){2,}\s*$').hasMatch(line)) {
        flushTable();
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, thickness: 1),
        ));
        i++;
        continue;
      }

      final tableCandidate = _splitTableRow(trimmed);
      final isLastLine = i == lines.length - 1;
      if (tableCandidate != null) {
        final nextRow = i + 1 < lines.length ? _splitTableRow(lines[i + 1].trim()) : null;
        final looksLikeHeader = nextRow != null && _isTableSeparatorRow(nextRow);
        if (looksLikeHeader || tableRows != null) {
          final rowIncomplete = isLastLine && !trimmed.endsWith('|');
          if (rowIncomplete) {
            i++;
            continue;
          }
          if (looksLikeHeader) {
            tableRows ??= [];
            tableRows!.add(tableCandidate);
            tableAlignments = _parseTableAlignments(nextRow!);
            i += 2;
          } else if (!_isTableSeparatorRow(tableCandidate)) {
            tableRows ??= [];
            tableRows!.add(tableCandidate);
            i++;
          } else {
            i++;
          }
          continue;
        }
      }
      if (tableRows != null) flushTable();

      if (isFence(trimmed)) {
        final fence = RegExp(r'^(```+|~~~+)').firstMatch(trimmed)!;
        final marker = fence.group(1)!;
        final info = trimmed.substring(fence.end).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length) {
          final candidate = lines[i].trimLeft();
          if (candidate.startsWith(marker)) break;
          codeLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++;
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AiCodeBlock(
            code: codeLines.join('\n'),
            language: info.isEmpty ? 'text' : info.split(RegExp(r'\s+')).first,
            s: s,
          ),
        ));
        continue;
      }

      if (RegExp(r'^(?: {4}|\t)').hasMatch(line)) {
        final codeLines = <String>[];
        while (i < lines.length) {
          final current = lines[i];
          if (current.trim().isEmpty) {
            codeLines.add('');
            i++;
            continue;
          }
          if (!RegExp(r'^(?: {4}|\t)').hasMatch(current)) break;
          codeLines.add(current.startsWith('\t')
              ? current.substring(1)
              : current.substring(current.length >= 4 ? 4 : current.length));
          i++;
        }
        while (codeLines.isNotEmpty && codeLines.last.isEmpty) {
          codeLines.removeLast();
        }
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AiCodeBlock(code: codeLines.join('\n'), language: 'text', s: s),
        ));
        continue;
      }

      if (trimmed.startsWith('>')) {
        final quoteLines = <String>[];
        String? admonitionType;
        bool firstLine = true;

        while (i < lines.length) {
          final currentTrimmed = lines[i].trim();
          if (!currentTrimmed.startsWith('>')) break;

          var content = currentTrimmed.replaceFirst(RegExp(r'^>\s?'), '');
          if (firstLine) {
            final tagMatch = RegExp(
              r'^\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION|INFO|SUCCESS|QUESTION)\]\s*',
              caseSensitive: false,
            ).firstMatch(content);
            if (tagMatch != null) {
              admonitionType = tagMatch.group(1)!.toUpperCase();
              content = content.substring(tagMatch.end);
            }
            firstLine = false;
          }
          quoteLines.add(content);
          i++;
        }

        final quoteText = quoteLines.join('\n').trim();
        final label = admonitionType == null ? null : _admonitionLabel(admonitionType!);
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  margin: const EdgeInsets.only(right: 11),
                  decoration: BoxDecoration(
                    color: s.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (label != null) ...[
                        Text(
                          label,
                          style: (bodyTextStyle ?? const TextStyle()).copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: s.onSurface,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                      ],
                      _formattedText(quoteText, s, bodyTextStyle: bodyTextStyle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
        continue;
      }

      final listMatch = RegExp(
        r'^(\s*)([-+*]|\d+[.)]|[a-zA-Z][.)])\s+(?:\[([ xX])\]\s+)?(.*)$',
      ).firstMatch(line);
      if (listMatch != null) {
        flushTable();
        final rendered = <Widget>[];

        while (i < lines.length) {
          final current = lines[i];
          final match = RegExp(
            r'^(\s*)([-+*]|\d+[.)]|[a-zA-Z][.)])\s+(?:\[([ xX])\]\s+)?(.*)$',
          ).firstMatch(current);
          if (match == null) break;

          final indent = match.group(1)!.replaceAll('\t', '    ').length;
          final marker = match.group(2)!;
          final checked = match.group(3);
          final content = match.group(4)!;
          final left = (indent ~/ 2) * 18.0;
          final isOrdered = RegExp(r'^(?:\d+[.)]|[a-zA-Z][.)])$').hasMatch(marker);
          final markerText = isOrdered ? marker : null;

          rendered.add(Padding(
            padding: EdgeInsets.only(left: left, bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 26,
                  child: checked != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            checked.toLowerCase() == 'x'
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 17,
                            color: checked.toLowerCase() == 'x'
                                ? s.primary
                                : s.onSurfaceVariant,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: markerText == null
                              ? Container(
                                  width: 5.5,
                                  height: 5.5,
                                  margin: const EdgeInsets.only(top: 8, left: 4),
                                  decoration: BoxDecoration(
                                    color: s.onSurfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : Text(
                                  markerText,
                                  style: (bodyTextStyle ?? const TextStyle()).copyWith(
                                    fontSize: 15.5,
                                    color: s.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                ),
                Expanded(
                  child: _formattedText(
                    content,
                    s,
                    fontWeight: checked?.toLowerCase() == 'x' ? FontWeight.normal : null,
                    bodyTextStyle: bodyTextStyle,
                  ),
                ),
              ],
            ),
          ));
          i++;
        }

        widgets.addAll(rendered);
        continue;
      }

      if (i + 1 < lines.length && trimmed.isNotEmpty && lines[i + 1].trimLeft().startsWith(':')) {
        flushTable();
        final term = trimmed;
        i++;
        final defs = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith(':')) {
          defs.add(lines[i].trimLeft().substring(1).trim());
          i++;
        }
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _formattedText(term, s, fontWeight: FontWeight.w700, bodyTextStyle: bodyTextStyle),
              for (final def in defs)
                Padding(
                  padding: const EdgeInsets.only(left: 18, top: 2),
                  child: _formattedText(def, s, bodyTextStyle: bodyTextStyle),
                ),
            ],
          ),
        ));
        continue;
      }

      final hardBreak = RegExp(r'(?: {2,}|\\)$').hasMatch(line);
      final content = hardBreak
          ? line.replaceFirst(RegExp(r'(?: {2,}|\\)$'), '')
          : trimmed;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _formattedText(content, s, forceLineBreak: hardBreak, bodyTextStyle: bodyTextStyle),
      ));
      i++;
    }

    flushTable();
    return widgets;
  }

  static Widget _buildDetailsBlock(String content, BrowseRichTextPalette s, {TextStyle? bodyTextStyle}) {
    String summary = 'Detalhes';
    var body = content;
    final summaryMatch = RegExp(r'<summary>(.*?)</summary>', dotAll: true).firstMatch(content);
    if (summaryMatch != null) {
      summary = summaryMatch.group(1)!.trim();
      body = content.replaceRange(summaryMatch.start, summaryMatch.end, '').trim();
    }
    return Theme(
      data: ThemeData.light(useMaterial3: true),
      child: ExpansionTile(
        title: Text(summary, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: s.onSurface)),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        iconColor: s.onSurfaceVariant,
        collapsedIconColor: s.onSurfaceVariant,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _formattedText(body, s, bodyTextStyle: bodyTextStyle),
          ),
        ],
      ),
    );
  }

  static List<String>? _splitTableRow(String line) {
    if (!line.contains('|')) return null;
    final value = line.trim();
    if (!(value.startsWith('|') || value.endsWith('|'))) return null;

    var body = value;
    if (body.startsWith('|')) body = body.substring(1);
    if (body.endsWith('|')) body = body.substring(0, body.length - 1);

    final cells = <String>[];
    final current = StringBuffer();
    bool escaped = false;
    for (final char in body.split('')) {
      if (escaped) {
        current.write(char);
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '|') {
        cells.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    if (escaped) current.write('\\');
    cells.add(current.toString().trim());
    return cells;
  }

  static bool _isTableSeparatorRow(List<String> row) {
    if (row.isEmpty) return false;
    return row.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell.trim()));
  }

  static List<TextAlign>? _parseTableAlignments(List<String> separatorRow) {
    final alignments = <TextAlign>[];
    for (final cell in separatorRow) {
      final t = cell.trim();
      if (t.startsWith(':') && t.endsWith(':')) {
        alignments.add(TextAlign.center);
      } else if (t.endsWith(':')) {
        alignments.add(TextAlign.right);
      } else {
        alignments.add(TextAlign.left);
      }
    }
    return alignments;
  }

  static String _admonitionLabel(String type) => switch (type) {
        'NOTE' => 'Nota',
        'TIP' => 'Dica',
        'IMPORTANT' => 'Importante',
        'WARNING' => 'Aviso',
        'CAUTION' => 'Cuidado',
        'INFO' => 'Informação',
        'SUCCESS' => 'Sucesso',
        'QUESTION' => 'Questão',
        _ => 'Nota',
      };

  // Cor fixa do código inline (azul fixo, não ligado ao tema).
  static const Color _kInlineCodeColor = Color(0xFF5B9DF0);

  static List<InlineSpan> inlineSpans(
    String raw,
    BrowseRichTextPalette s, {
    double fontSize = 15.5,
    bool forceLineBreak = false,
  }) {
    final processed = _normalizeInlineMarkdown(raw);
    final spans = <InlineSpan>[];

    final pattern = RegExp(
      r'(\$\$[^$\n]+?\$\$)|'
      r'(\$[^$\n]+?\$)|'
      r'(!?\[[^\]\n]+\]\([^\)\n]+(?:\s+[\x22\x27][^\x22\x27]*[\x22\x27])?\))|'
      r'(\*\*\*[^*\n]+?\*\*\*)|'
      r'(\*\*[^*\n]+?\*\*|__[^_\n]+?__)|'
      r'(~~[^~\n]+?~~)|'
      r'(\*(?!\*)(?!\s)[^*\n]+?(?<!\s)(?<!\*)\*(?!\*)|_(?!\s)[^_\n]+?(?<!\s)_)|'
      r'(==[^=\n]+?==)|'
      r'(\+\+[^+\n]+?\+\+)|'
      r'(<sup>[^<]+</sup>)|'
      r'(<sub>[^<]+</sub>)|'
      r'(```[^`\n]*```)|'
      r'(`[^`\n]+?`)|'
      r'(\^\([^\)\n]+\)|\^\w+)|'
      r'(\~\([^\)\n]+\)|\~\w+)|'
      r'(https?://[^\s<>]+)|'
      r'(?<=\s|^)([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})(?=\s|$)|'
      r'(<br\s*/?>)|'
      r'(\\)$',
      multiLine: true,
    );

    int last = 0;
    for (final m in pattern.allMatches(processed)) {
      if (m.start > last) {
        spans.add(TextSpan(text: _unescapeInline(processed.substring(last, m.start))));
      }

      final token = m.group(0)!;
      if (token.startsWith('\$\$') && token.endsWith('\$\$')) {
        final expr = token.substring(2, token.length - 2);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MathInline(expression: expr, s: s, block: false),
        ));
      } else if (token.startsWith(r'$')) {
        final expr = token.substring(1, token.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MathInline(expression: expr, s: s, block: false),
        ));
      } else if (token.startsWith('![')) {
        final match = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)').firstMatch(token);
        if (match != null) {
          final alt = match.group(1)!.trim();
          final imageUrl = _richSafeUrl(match.group(2));
          if (imageUrl.isNotEmpty) {
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 260,
                    height: 150,
                    fit: BoxFit.cover,
                    semanticLabel: alt.isEmpty ? 'Imagem da resposta' : alt,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : Container(width: 260, height: 150, color: s.hover, alignment: Alignment.center,
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: s.primary))),
                    errorBuilder: (_, __, ___) => Container(
                      width: 260,
                      height: 76,
                      color: s.hover,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(10),
                      child: Text(alt.isEmpty ? 'Imagem indisponível' : alt,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: s.onSurfaceVariant, fontSize: 11.5)),
                    ),
                  ),
                ),
              ),
            ));
          } else {
            spans.add(TextSpan(text: alt.isEmpty ? 'imagem indisponível' : alt));
          }
        }
      } else if (token.startsWith('[')) {
        final match = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)').firstMatch(token);
        if (match != null) {
          final label = match.group(1)!;
          final url = match.group(2)!;
          spans.add(TextSpan(
            text: label,
            style: const TextStyle(decoration: TextDecoration.underline),
            recognizer: null,
            semanticsLabel: '$label — $url',
          ));
        }
      } else if (token.startsWith('***')) {
        spans.add(TextSpan(
          text: token.substring(3, token.length - 3),
          style: const TextStyle(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
        ));
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(TextSpan(
          text: _unescapeInline(token.substring(2, token.length - 2)),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (token.startsWith('~~')) {
        spans.add(TextSpan(
          text: _unescapeInline(token.substring(2, token.length - 2)),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ));
      } else if (token.startsWith('==')) {
        final value = token.substring(2, token.length - 2);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
            decoration: BoxDecoration(
              color: s.primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                color: s.primary,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
        ));
      } else if (token.startsWith('++')) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(decoration: TextDecoration.underline),
        ));
      } else if (token.startsWith('<sup>')) {
        final value = token.substring(5, token.length - 6);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Transform.translate(
            offset: Offset(0, -fontSize * 0.35),
            child: Text(value, style: TextStyle(fontSize: fontSize * 0.7, height: 1.0)),
          ),
        ));
      } else if (token.startsWith('<sub>')) {
        final value = token.substring(5, token.length - 6);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: Transform.translate(
            offset: Offset(0, fontSize * 0.12),
            child: Text(value, style: TextStyle(fontSize: fontSize * 0.7, height: 1.0)),
          ),
        ));
      } else if (token.startsWith('```')) {
        spans.add(TextSpan(
          text: token.substring(3, token.length - 3),
          style: const TextStyle(fontFamily: 'monospace'),
        ));
      } else if (token.startsWith('`')) {
        // Código inline — fundo escuro, cantos arredondados (9px,
        // "curvado mas não pill"), borda FINA (0.6) s.outline, texto
        // AZUL FIXO #5B9DF0. WidgetSpan (não TextSpan.backgroundColor)
        // porque só um Container real dá cantos arredondados + borda.
        final value = _unescapeInline(token.substring(1, token.length - 1));
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: s.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: s.outline, width: 0.6),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize - 1,
                color: _kInlineCodeColor,
                height: 1.25,
              ),
            ),
          ),
        ));
      } else if (token.startsWith('^')) {
        final value = token.startsWith('^(')
            ? token.substring(2, token.length - 1)
            : token.substring(1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Transform.translate(
            offset: Offset(0, -fontSize * 0.35),
            child: Text(value, style: TextStyle(fontSize: fontSize * 0.7, height: 1.0)),
          ),
        ));
      } else if (token.startsWith('~')) {
        final value = token.startsWith('~(')
            ? token.substring(2, token.length - 1)
            : token.substring(1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: Transform.translate(
            offset: Offset(0, fontSize * 0.12),
            child: Text(value, style: TextStyle(fontSize: fontSize * 0.7, height: 1.0)),
          ),
        ));
      } else if (token.startsWith('http://') || token.startsWith('https://')) {
        spans.add(TextSpan(
          text: token,
          style: const TextStyle(decoration: TextDecoration.underline),
          semanticsLabel: token,
        ));
      } else if (token.startsWith('<br')) {
        spans.add(const TextSpan(text: '\n'));
      } else if (token == r'\\') {
        spans.add(const TextSpan(text: '\n'));
      } else if (token.startsWith('*') || token.startsWith('_')) {
        spans.add(TextSpan(
          text: _unescapeInline(token.substring(1, token.length - 1)),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (token.contains('@')) {
        spans.add(TextSpan(
          text: token,
          style: const TextStyle(decoration: TextDecoration.underline),
        ));
      }
      last = m.end;
    }

    if (last < processed.length) {
      spans.add(TextSpan(text: _unescapeInline(processed.substring(last))));
    }
    if (forceLineBreak) spans.add(const TextSpan(text: '\n'));
    return spans;
  }

  static String _normalizeInlineMarkdown(String value) {
    var result = value.replaceAll('\u200B', '');
    kEmojiShortcodes.forEach((code, replacement) {
      result = result.replaceAll(code, replacement);
    });
    return result;
  }

  static String _unescapeInline(String value) {
    return value.replaceAllMapped(RegExp(r'\\([\\`*_[\]{}()#+.!|>~-])'), (m) => m.group(1)!);
  }

  static Widget _formattedText(
    String raw,
    BrowseRichTextPalette s, {
    double fontSize = 15.5,
    FontWeight? fontWeight,
    bool forceLineBreak = false,
    TextStyle? bodyTextStyle,
  }) {
    final base = TextStyle(
      color: s.onSurface,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      height: 1.45,
    );
    final merged = bodyTextStyle != null
        ? base.merge(bodyTextStyle).copyWith(
              fontSize: fontSize,
              fontWeight: fontWeight ?? bodyTextStyle.fontWeight ?? FontWeight.normal,
            )
        : base;

    return SelectableText.rich(
      TextSpan(
        style: merged,
        children: inlineSpans(
          raw,
          s,
          fontSize: fontSize,
          forceLineBreak: forceLineBreak,
        ),
      ),
    );
  }
}

class _AiTable extends StatelessWidget {
  final List<List<String>> rows;
  final BrowseRichTextPalette s;
  final List<TextAlign>? alignments;

  const _AiTable({
    required this.rows,
    required this.s,
    this.alignments,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final header = rows.first;
    final body = rows.length > 1 ? rows.sublist(1) : <List<String>>[];

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(color: s.outline.withOpacity(0.4), width: 0.7),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              decoration: BoxDecoration(color: s.hover),
              children: header
                  .asMap()
                  .entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Align(
                          alignment: _alignmentFor(e.key, alignments),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: s.onSurface),
                              children: _RichTextBlockParser.inlineSpans(
                                  e.value, s, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            for (final row in body)
              TableRow(
                children: row
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: Align(
                            alignment: _alignmentFor(e.key, alignments),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 13.5, color: s.onSurface),
                                children: _RichTextBlockParser.inlineSpans(
                                    e.value, s, fontSize: 13.5),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Alignment _alignmentFor(int colIndex, List<TextAlign>? alignments) {
    if (alignments != null && colIndex < alignments.length) {
      switch (alignments[colIndex]) {
        case TextAlign.center: return Alignment.center;
        case TextAlign.right: return Alignment.centerRight;
        default: return Alignment.centerLeft;
      }
    }
    return Alignment.centerLeft;
  }
}

Widget buildAiTableFromWidgetJson(Map<String, dynamic> json, BrowseRichTextPalette s) {
  final headers = (json['headers'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
  final bodyRows = (json['rows'] as List?)
          ?.map((r) => (r as List).map((c) => c.toString()).toList())
          .toList() ??
      const <List<String>>[];
  if (headers.isEmpty && bodyRows.isEmpty) return const SizedBox.shrink();
  final allRows = <List<String>>[if (headers.isNotEmpty) headers, ...bodyRows];
  return Container(
    constraints: const BoxConstraints(maxWidth: 560),
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: _AiTable(rows: allRows, s: s),
  );
}

// ══════════════════════════════════════════════════════════════
// SYNTAX HIGHLIGHTING
// ══════════════════════════════════════════════════════════════

class _TokenPattern {
  final RegExp regex;
  final Color? color;
  final FontStyle? fontStyle;
  final FontWeight? fontWeight;

  const _TokenPattern(this.regex, {this.color, this.fontStyle, this.fontWeight});
}

class _CodeTokenColors {
  final Color background;
  final Color baseText;
  final Color tag;
  final Color attr;
  final Color string;
  final Color stringEscape;
  final Color comment;
  final Color doctype;
  final Color punct;
  final Color keyword;
  final Color keywordImport;
  final Color number;
  final Color function;
  final Color type;
  final Color constant;
  final Color operatorColor;
  final Color self;
  final Color decorator;
  final Color builtin;
  final Color property;

  const _CodeTokenColors({
    required this.background,
    required this.baseText,
    required this.tag,
    required this.attr,
    required this.string,
    required this.stringEscape,
    required this.comment,
    required this.doctype,
    required this.punct,
    required this.keyword,
    required this.keywordImport,
    required this.number,
    required this.function,
    required this.type,
    required this.constant,
    required this.operatorColor,
    required this.self,
    required this.decorator,
    required this.builtin,
    required this.property,
  });

  static const dark = _CodeTokenColors(
    background: Color(0xFF161616),
    baseText: Color(0xFFE8E8E8),
    tag: Color(0xFF79B8FF),
    attr: Color(0xFF9CDCFE),
    string: Color(0xFFE3B341),
    stringEscape: Color(0xFFFFD866),
    comment: Color(0xFF6A737D),
    doctype: Color(0xFF6CC7F5),
    punct: Color(0xFF9198A1),
    keyword: Color(0xFF79B8FF),
    keywordImport: Color(0xFFFF9E64),
    number: Color(0xFF79C0FF),
    function: Color(0xFF8AB4F8),
    type: Color(0xFFFFB454),
    constant: Color(0xFF56C7FF),
    operatorColor: Color(0xFF8AB4F8),
    self: Color(0xFFE06C75),
    decorator: Color(0xFF9ED072),
    builtin: Color(0xFF6FE3C4),
    property: Color(0xFF7EE7FC),
  );

  static const light = _CodeTokenColors(
    background: Color(0xFFF6F6F7),
    baseText: Color(0xFF1F2328),
    tag: Color(0xFF1A73E8),
    attr: Color(0xFF0B6FB0),
    string: Color(0xFF8A5A00),
    stringEscape: Color(0xFF9A6A00),
    comment: Color(0xFF6E7781),
    doctype: Color(0xFF0B6FB0),
    punct: Color(0xFF57606A),
    keyword: Color(0xFFCF222E),
    keywordImport: Color(0xFFB35900),
    number: Color(0xFF0550AE),
    function: Color(0xFF1A73E8),
    type: Color(0xFF9A5B00),
    constant: Color(0xFF0B6FB0),
    operatorColor: Color(0xFF1A73E8),
    self: Color(0xFFB3272D),
    decorator: Color(0xFF3F7D20),
    builtin: Color(0xFF116B5C),
    property: Color(0xFF0B6FB0),
  );

  static _CodeTokenColors of(bool isDark) => isDark ? dark : light;
}

class AiCodeBlock extends StatefulWidget {
  final String code;
  final String language;
  final BrowseRichTextPalette s;

  const AiCodeBlock({
    super.key,
    required this.code,
    required this.language,
    required this.s,
  });

  @override
  State<AiCodeBlock> createState() => _AiCodeBlockState();
}

class _AiCodeBlockState extends State<AiCodeBlock> {
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.code));
      if (!mounted) return;
      setState(() => _copied = true);
      _copiedTimer?.cancel();
      _copiedTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (_) {
      // A indisponibilidade temporária da área de transferência não deve
      // interromper a renderização da resposta.
    }
  }

  String get _displayLanguage {
    final lang = widget.language.toLowerCase().trim();
    const labels = {
      'dart': 'Dart',
      'js': 'JavaScript',
      'javascript': 'JavaScript',
      'jsx': 'JSX',
      'ts': 'TypeScript',
      'typescript': 'TypeScript',
      'tsx': 'TSX',
      'py': 'Python',
      'python': 'Python',
      'html': 'HTML',
      'htm': 'HTML',
      'xml': 'XML',
      'svg': 'SVG',
      'css': 'CSS',
      'scss': 'SCSS',
      'bash': 'Bash',
      'shell': 'Shell',
      'sh': 'Shell',
      'sql': 'SQL',
      'markdown': 'Markdown',
      'md': 'Markdown',
      'go': 'Go',
      'rust': 'Rust',
      'kotlin': 'Kotlin',
      'swift': 'Swift',
      'c': 'C',
      'cpp': 'C++',
      'c++': 'C++',
      'csharp': 'C#',
      'cs': 'C#',
      'java': 'Java',
      'json': 'JSON',
      'yaml': 'YAML',
      'yml': 'YAML',
      'toml': 'TOML',
      'ini': 'INI',
      'text': 'Texto',
    };
    return labels[lang] ?? (lang.isEmpty ? 'Texto' : lang);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _CodeTokenColors.of(widget.s.isDark);
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 15.0,
      height: 1.7,
      color: tokens.baseText,
    );

    final codeSpans = _highlightCode(widget.code, widget.language, baseStyle, tokens);

    final appBarColor = Color.alphaBlend(
      (widget.s.isDark ? Colors.black : Colors.white).withOpacity(0.10),
      tokens.background,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAppBar(appBarColor, tokens),
          _buildCodeBody(codeSpans, baseStyle),
        ],
      ),
    );
  }

  Widget _buildAppBar(Color appBarColor, _CodeTokenColors tokens) {
    final labelColor = tokens.comment;
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: BoxDecoration(color: appBarColor),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _displayLanguage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: labelColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
          _BareIconButton(
            svgAsset: _copied ? 'check.svg' : 'copy.svg',
            color: _copied ? const Color(0xFF4ADE80) : labelColor,
            hoverColor: tokens.baseText,
            onTap: _copy,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBody(List<TextSpan> spans, TextStyle baseStyle) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: SelectableText.rich(
        TextSpan(style: baseStyle, children: spans),
        textAlign: TextAlign.left,
      ),
    );
  }
}

class _BareIconButton extends StatefulWidget {
  final String svgAsset;
  final Color color;
  final Color hoverColor;
  final VoidCallback? onTap;

  const _BareIconButton({
    required this.svgAsset,
    required this.color,
    required this.hoverColor,
    this.onTap,
  });

  @override
  State<_BareIconButton> createState() => _BareIconButtonState();
}

class _BareIconButtonState extends State<_BareIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              widget.svgAsset == 'check.svg' ? Icons.check_rounded : Icons.copy_rounded,
              key: ValueKey(widget.svgAsset),
              size: 16,
              color: _hover ? widget.hoverColor : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

List<TextSpan> _highlightCode(String code, String language, TextStyle baseStyle, _CodeTokenColors tokens) {
  final lang = language.toLowerCase();

  if (lang == 'html' || lang == 'htm' || lang == 'xml' || lang == 'svg') {
    return _highlightHtml(code, baseStyle, tokens);
  }

  final patterns = _patternsForLanguage(lang, tokens);
  final lines = code.split('\n');
  final spans = <TextSpan>[];

  for (int i = 0; i < lines.length; i++) {
    if (i > 0) spans.add(TextSpan(text: '\n', style: baseStyle));
    spans.addAll(_highlightLineGeneric(lines[i], patterns, baseStyle));
  }

  return spans;
}

List<TextSpan> _highlightHtml(String code, TextStyle baseStyle, _CodeTokenColors tokens) {
  final styleBlockPattern = RegExp(r'<style[^>]*>([\s\S]*?)</style>', caseSensitive: false);
  if (styleBlockPattern.hasMatch(code)) {
    return _highlightHtmlWithCss(code, baseStyle, tokens);
  }

  final lines = code.split('\n');
  final spans = <TextSpan>[];

  for (int i = 0; i < lines.length; i++) {
    if (i > 0) spans.add(TextSpan(text: '\n', style: baseStyle));
    spans.addAll(_highlightHtmlLine(lines[i], baseStyle, tokens));
  }

  return spans;
}

List<TextSpan> _highlightHtmlWithCss(String code, TextStyle baseStyle, _CodeTokenColors tokens) {
  final spans = <TextSpan>[];
  int last = 0;
  final cssPattern = RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false);
  for (final m in cssPattern.allMatches(code)) {
    if (m.start > last) {
      spans.addAll(_highlightHtmlLine(code.substring(last, m.start), baseStyle, tokens));
    }
    final cssContent = code.substring(m.start, m.end);
    final cssInnerMatch = RegExp(r'<style[^>]*>([\s\S]*?)</style>', caseSensitive: false).firstMatch(cssContent);
    if (cssInnerMatch != null) {
      spans.add(TextSpan(
        text: '<style>',
        style: baseStyle.copyWith(color: tokens.tag, fontWeight: FontWeight.w600),
      ));
      final cssLines = cssInnerMatch.group(1)!.split('\n');
      for (final line in cssLines) {
        spans.addAll(_highlightLineGeneric(line, _patternsForLanguage('css', tokens), baseStyle));
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
      spans.add(TextSpan(
        text: '</style>',
        style: baseStyle.copyWith(color: tokens.tag, fontWeight: FontWeight.w600),
      ));
    } else {
      spans.add(TextSpan(text: cssContent, style: baseStyle));
    }
    last = m.end;
  }
  if (last < code.length) {
    spans.addAll(_highlightHtmlLine(code.substring(last), baseStyle, tokens));
  }
  return spans;
}

List<TextSpan> _highlightHtmlLine(String line, TextStyle baseStyle, _CodeTokenColors tokens) {
  final spans = <TextSpan>[];

  final commentMatch = RegExp(r'^(\s*)(<!--.*-->)(\s*)$').firstMatch(line);
  if (commentMatch != null) {
    spans.add(TextSpan(text: commentMatch.group(1), style: baseStyle));
    spans.add(TextSpan(
      text: commentMatch.group(2),
      style: baseStyle.copyWith(color: tokens.comment, fontStyle: FontStyle.italic),
    ));
    spans.add(TextSpan(text: commentMatch.group(3), style: baseStyle));
    return spans;
  }

  final doctypeMatch = RegExp(r'^(\s*)(<!DOCTYPE[^>]*>)(\s*)$', caseSensitive: false).firstMatch(line);
  if (doctypeMatch != null) {
    spans.add(TextSpan(text: doctypeMatch.group(1), style: baseStyle));
    spans.add(TextSpan(
      text: doctypeMatch.group(2),
      style: baseStyle.copyWith(color: tokens.doctype),
    ));
    spans.add(TextSpan(text: doctypeMatch.group(3), style: baseStyle));
    return spans;
  }

  int i = 0;
  StringBuffer buffer = StringBuffer();

  while (i < line.length) {
    if (line[i] == '<') {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString(), style: baseStyle));
        buffer.clear();
      }
      int end = line.indexOf('>', i);
      if (end == -1) end = line.length - 1;
      final tagContent = line.substring(i, end + 1);
      spans.addAll(_highlightHtmlTag(tagContent, baseStyle, tokens));
      i = end + 1;
    } else {
      buffer.write(line[i]);
      i++;
    }
  }

  if (buffer.isNotEmpty) {
    spans.add(TextSpan(text: buffer.toString(), style: baseStyle));
  }

  return spans;
}

List<TextSpan> _highlightHtmlTag(String tag, TextStyle baseStyle, _CodeTokenColors tokens) {
  final spans = <TextSpan>[];
  final isClosing = tag.startsWith('</');
  final innerStart = isClosing ? 2 : 1;
  final innerEnd = tag.endsWith('>') ? tag.length - 1 : tag.length;
  final inner = tag.substring(innerStart, innerEnd);

  final nameMatch = RegExp(r'^([a-zA-Z0-9-]+)').firstMatch(inner);
  final tagName = nameMatch?.group(1) ?? '';
  final restStart = nameMatch != null ? nameMatch.group(0)!.length : 0;
  final rest = inner.substring(restStart);

  spans.add(TextSpan(
    text: isClosing ? '</' : '<',
    style: baseStyle.copyWith(color: tokens.punct),
  ));

  if (tagName.isNotEmpty) {
    spans.add(TextSpan(
      text: tagName,
      style: baseStyle.copyWith(color: tokens.tag, fontWeight: FontWeight.w600),
    ));
  }

  final attrRegex = RegExp(r'''([a-zA-Z-]+)(\s*=\s*)("([^"]*)"|'([^']*)')|([a-zA-Z-]+)''');
  int lastIndex = 0;

  for (final m in attrRegex.allMatches(rest)) {
    if (m.start > lastIndex) {
      spans.add(TextSpan(
        text: rest.substring(lastIndex, m.start),
        style: baseStyle.copyWith(color: tokens.punct),
      ));
    }

    if (m.group(1) != null) {
      spans.add(TextSpan(text: m.group(1)!, style: baseStyle.copyWith(color: tokens.attr)));
      spans.add(TextSpan(text: m.group(2)!, style: baseStyle.copyWith(color: tokens.punct)));
      spans.add(TextSpan(text: m.group(3)!, style: baseStyle.copyWith(color: tokens.string)));
    } else if (m.group(6) != null) {
      spans.add(TextSpan(text: m.group(6)!, style: baseStyle.copyWith(color: tokens.attr)));
    }
    lastIndex = m.end;
  }

  if (lastIndex < rest.length) {
    spans.add(TextSpan(
      text: rest.substring(lastIndex),
      style: baseStyle.copyWith(color: tokens.punct),
    ));
  }

  spans.add(TextSpan(
    text: tag.endsWith('/>') ? '/>' : '>',
    style: baseStyle.copyWith(color: tokens.punct),
  ));

  return spans;
}

List<TextSpan> _highlightLineGeneric(String line, List<_TokenPattern> patterns, TextStyle baseStyle) {
  final spans = <TextSpan>[];
  int index = 0;

  while (index < line.length) {
    bool matched = false;

    for (final pattern in patterns) {
      final match = pattern.regex.matchAsPrefix(line, index);
      if (match != null && match.group(0)!.isNotEmpty) {
        final text = match.group(0)!;
        spans.add(TextSpan(
          text: text,
          style: baseStyle.copyWith(
            color: pattern.color,
            fontStyle: pattern.fontStyle,
            fontWeight: pattern.fontWeight,
          ),
        ));
        index = match.end;
        matched = true;
        break;
      }
    }

    if (!matched) {
      spans.add(TextSpan(text: line[index], style: baseStyle));
      index++;
    }
  }

  return spans;
}

List<_TokenPattern> _patternsForLanguage(String language, _CodeTokenColors tokens) {
  switch (language) {
    case 'dart':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: tokens.decorator),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: tokens.string),
        _TokenPattern(RegExp(r'\\[nrt"\047\\$]'), color: tokens.stringEscape),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\bthis\b|\bsuper\b'), color: tokens.self, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'\b(?:import|export|library|part|show|hide|deferred|as)\b'), color: tokens.keywordImport),
        _TokenPattern(RegExp(r'\b(?:abstract|assert|async|await|break|case|catch|class|const|continue|covariant|default|do|dynamic|else|enum|extends|extension|external|factory|final|finally|for|Function|get|if|implements|in|interface|is|late|mixin|new|null|on|operator|required|rethrow|return|set|static|switch|sync|throw|try|typedef|var|void|while|with|yield)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:int|double|String|bool|List|Map|Set|Object|void|dynamic|Future|Stream|Widget|BuildContext|Duration|Color|Offset|Size|Rect)\b'), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\bprint\b(?=\()'), color: tokens.builtin),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: tokens.type),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: tokens.property),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'=>|==|!=|<=|>=|&&|\|\||\?\?|\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'python':
      return [
        _TokenPattern(RegExp(r'#[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'@[a-zA-Z_][\w.]*'), color: tokens.decorator),
        _TokenPattern(RegExp(r'"""[\s\S]*?"""'), color: tokens.string),
        _TokenPattern(RegExp(r"'''[\s\S]*?'''"), color: tokens.string),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: tokens.string),
        _TokenPattern(RegExp(r'\\[nrt"\047\\]'), color: tokens.stringEscape),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\bself\b|\bcls\b'), color: tokens.self, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'\b(?:import|from|as)\b'), color: tokens.keywordImport),
        _TokenPattern(RegExp(r'\b(?:and|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|global|if|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:int|float|str|bool|list|dict|set|tuple|object|bytes|frozenset)\b'), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:print|len|range|enumerate|zip|map|filter|sorted|sum|min|max|abs|isinstance|super|open|input|type)\b(?=\()'), color: tokens.builtin),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: tokens.type),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: tokens.property),
        _TokenPattern(RegExp(r'\b(?:True|False|None)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'==|!=|<=|>=|\*\*|//|->|[+\-*/%=<>!&|^~:]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'javascript':
    case 'js':
    case 'jsx':
    case 'typescript':
    case 'ts':
    case 'tsx':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: tokens.decorator),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: tokens.string),
        _TokenPattern(RegExp(r'`(?:\\`|[^`])*`'), color: tokens.string),
        _TokenPattern(RegExp(r'\\[nrt"\047\\`]'), color: tokens.stringEscape),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\bthis\b'), color: tokens.self, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'\b(?:import|export|from|default)\b'), color: tokens.keywordImport),
        _TokenPattern(RegExp(r'\b(?:var|let|const|function|return|if|else|for|while|do|switch|case|break|continue|new|class|extends|super|typeof|instanceof|in|of|async|await|try|catch|finally|throw|static|get|set|yield|interface|type|enum|implements|public|private|protected|readonly|namespace|declare)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:string|number|boolean|any|void|never|unknown|object|Array|Promise|Map|Set)\b'), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:console|Math|JSON|Object|Array|parseInt|parseFloat|setTimeout|setInterval)\b'), color: tokens.builtin),
        _TokenPattern(RegExp(r'\b(?:true|false|null|undefined)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: tokens.type),
        _TokenPattern(RegExp(r'\b[a-zA-Z_$]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'\.[a-zA-Z_$]\w*(?!\()'), color: tokens.property),
        _TokenPattern(RegExp(r'=>|===|!==|==|!=|<=|>=|&&|\|\||\?\?|\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'css':
    case 'scss':
      return [
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: tokens.string),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?(?:px|em|rem|%|vh|vw|s|ms|deg)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'#[0-9a-fA-F]{3,8}\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'\.[a-zA-Z_-][\w-]*'), color: tokens.function),
        _TokenPattern(RegExp(r'#[a-zA-Z_-][\w-]*'), color: tokens.decorator),
        _TokenPattern(RegExp(r'[a-zA-Z-]+(?=\s*:)'), color: tokens.attr),
        _TokenPattern(RegExp(r'\b(?:a|abbr|address|area|article|aside|audio|b|base|bdi|bdo|blockquote|body|br|button|canvas|caption|cite|code|col|colgroup|data|datalist|dd|del|details|dfn|dialog|div|dl|dt|em|embed|fieldset|figcaption|figure|footer|form|h1|h2|h3|h4|h5|h6|head|header|hgroup|hr|html|i|iframe|img|input|ins|kbd|label|legend|li|link|main|map|mark|menu|meta|meter|nav|noscript|object|ol|optgroup|option|output|p|picture|pre|progress|q|rp|rt|ruby|s|samp|script|section|select|slot|small|source|span|strong|style|sub|summary|sup|table|tbody|td|template|textarea|tfoot|th|thead|time|title|tr|track|u|ul|var|video|wbr)\b'), color: tokens.tag),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'bash':
    case 'shell':
    case 'sh':
      return [
        _TokenPattern(RegExp(r'#[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: tokens.string),
        _TokenPattern(RegExp(r'\$\{?[a-zA-Z_]\w*\}?'), color: tokens.property),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:if|then|else|elif|fi|for|while|do|done|case|esac|function|export|readonly|local|return|exit)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:echo|printf|source|cd|ls|grep|awk|sed|curl|wget|cat|mkdir|rm|cp|mv|chmod|pip|npm|flutter|dart|git)\b'), color: tokens.builtin),
        _TokenPattern(RegExp(r'--?[a-zA-Z-]+'), color: tokens.attr),
        _TokenPattern(RegExp(r'[|&;><]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'sql':
      return [
        _TokenPattern(RegExp(r'--[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: tokens.string),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:SELECT|FROM|WHERE|INSERT|INTO|VALUES|UPDATE|DELETE|CREATE|TABLE|ALTER|DROP|INDEX|VIEW|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AS|AND|OR|NOT|NULL|PRIMARY|KEY|FOREIGN|REFERENCES|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|DISTINCT)\b', caseSensitive: false), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:COUNT|SUM|AVG|MIN|MAX|COALESCE|CAST|NOW|CURRENT_DATE)\b', caseSensitive: false), color: tokens.builtin),
        _TokenPattern(RegExp(r'\b(?:int|varchar|char|text|date|datetime|timestamp|decimal|float|double|boolean|bool)\b', caseSensitive: false), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'=|<>|!=|<=|>=|[+\-*/<>]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'markdown':
    case 'md':
      return [
        _TokenPattern(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), color: tokens.string),
        _TokenPattern(RegExp(r'(\*\*|__)(.*?)\1'), color: tokens.keyword),
        _TokenPattern(RegExp(r'(\*|_)(.*?)\1'), color: tokens.tag),
        _TokenPattern(RegExp(r'^\s{0,3}#{1,6}\s.*$'), color: tokens.type),
        _TokenPattern(RegExp(r'^\s{0,3}>.*$'), color: tokens.comment),
        _TokenPattern(RegExp(r'`[^`]+`'), color: tokens.builtin),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'go':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r'`[^`]*`'), color: tokens.string),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:func|package|import|return|if|else|for|range|go|defer|select|case|default|break|continue|switch|type|struct|interface|map|chan|var|const|nil|true|false)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:string|int|float64|bool|byte|rune|error|uint|int8|int16|int32|int64|uint8|uint16|uint32|uint64)\b'), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:fmt|len|cap|print|println|append|copy|make|new)\b'), color: tokens.builtin),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: tokens.type),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: tokens.property),
        _TokenPattern(RegExp(r'==|!=|<=|>=|:=|\+\+|--|[+\-*/%=<>!&|^~]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'rust':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r'#\[[^\]]+\]'), color: tokens.decorator),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:fn|let|mut|const|static|if|else|for|while|loop|match|return|impl|trait|struct|enum|pub|use|mod|self|super|crate|where|async|await)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:u8|u16|u32|u64|usize|i8|i16|i32|i64|isize|f32|f64|bool|String|Vec|Option|Result|Box|HashMap)\b'), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:println|print|format|vec|panic|assert|Some|None|Ok|Err)\b'), color: tokens.builtin),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: tokens.type),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: tokens.property),
        _TokenPattern(RegExp(r'=>|==|!=|<=|>=|::|\+\+|--|[+\-*/%=<>!&|^~]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'kotlin':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: tokens.decorator),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:fun|val|var|class|object|interface|enum|data|sealed|if|else|for|while|do|return|when|in|is|as|new|this|super|companion|init|constructor)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:String|Int|Double|Boolean|Float|Long|Short|Byte|Char|Unit|Any|List|Map|Set)\b'), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:print|println|require|assert|run|let|apply|also|with)\b'), color: tokens.builtin),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: tokens.type),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: tokens.property),
        _TokenPattern(RegExp(r'->|==|!=|<=|>=|&&|\|\||\?\?|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'swift':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: tokens.decorator),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:func|var|let|class|struct|enum|protocol|extension|if|else|for|while|repeat|return|guard|switch|case|default|break|continue|import|init|self|super|where|as|is|try|catch|throw)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:String|Int|Double|Bool|Float|Character|Array|Dictionary|Set|Optional|Any)\b'), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:print|assert|map|filter|reduce|first|last|append|count)\b'), color: tokens.builtin),
        _TokenPattern(RegExp(r'\b(?:true|false|nil)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: tokens.type),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: tokens.property),
        _TokenPattern(RegExp(r'->|==|!=|<=|>=|&&|\|\||\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'c':
    case 'cpp':
    case 'c++':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])'"), color: tokens.string),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:int|float|double|char|void|bool|auto|long|short|unsigned|signed|size_t|uint8_t|uint16_t|uint32_t|uint64_t|int8_t|int16_t|int32_t|int64_t)\b'), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:if|else|for|while|do|return|break|continue|switch|case|default|goto|typedef|struct|union|enum|static|const|volatile|extern|inline|sizeof|new|delete|this|class|namespace|using|template|typename)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:true|false|null|NULL|nullptr)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: tokens.type),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: tokens.property),
        _TokenPattern(RegExp(r'->|==|!=|<=|>=|&&|\|\||\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'csharp':
    case 'cs':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: tokens.decorator),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:int|long|short|byte|float|double|decimal|char|string|bool|void|object|var|dynamic)\b'), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:if|else|for|while|do|return|break|continue|switch|case|default|goto|class|struct|enum|interface|namespace|using|public|private|protected|internal|static|readonly|const|virtual|override|abstract|sealed|async|await|try|catch|finally|throw|new|this|base|is|as|in|out|ref)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: tokens.type),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: tokens.property),
        _TokenPattern(RegExp(r'=>|==|!=|<=|>=|&&|\|\||\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'java':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: tokens.decorator),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:int|long|short|byte|float|double|char|boolean|void|String|Object)\b'), color: tokens.type, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:if|else|for|while|do|return|break|continue|switch|case|default|class|interface|enum|package|import|public|private|protected|static|final|abstract|synchronized|transient|volatile|try|catch|finally|throw|new|this|super|extends|implements|instanceof)\b'), color: tokens.keyword),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: tokens.type),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: tokens.property),
        _TokenPattern(RegExp(r'->|==|!=|<=|>=|&&|\|\||\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'json':
      return [
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'[{}[\]\,:]'), color: tokens.punct),
      ];

    case 'yaml':
    case 'yml':
      return [
        _TokenPattern(RegExp(r'#[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: tokens.string),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'[:\-]'), color: tokens.punct),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'toml':
      return [
        _TokenPattern(RegExp(r'#[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: tokens.constant),
        _TokenPattern(RegExp(r'\[\[?.*?\]\]?'), color: tokens.type),
        _TokenPattern(RegExp(r'='), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    case 'ini':
      return [
        _TokenPattern(RegExp(r'#[^\n]*|;[^\n]*'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\[([^\]]+)\]'), color: tokens.type),
        _TokenPattern(RegExp(r'='), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];

    default:
      return [
        _TokenPattern(RegExp(r'//[^\n]*|#[^\n]*|/\*.*?\*/'), color: tokens.comment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: tokens.string),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: tokens.string),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: tokens.number),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: tokens.function),
        _TokenPattern(RegExp(r'[+\-*/%=<>!&|^~?:]'), color: tokens.operatorColor),
        _TokenPattern(RegExp(r'[^\s\w]'), color: tokens.punct),
      ];
  }
}

