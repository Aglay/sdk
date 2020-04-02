// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Declares miscellaneous utility functions and constants for type flow
/// analysis.
library vm.transformations.type_flow.utils;

import 'package:kernel/ast.dart'
    show
        Class,
        Constructor,
        DartType,
        FunctionNode,
        Member,
        Nullability,
        Procedure,
        VariableDeclaration;

const bool kPrintTrace =
    const bool.fromEnvironment('global.type.flow.print.trace');

const bool kPrintDebug =
    const bool.fromEnvironment('global.type.flow.print.debug');

const bool kPrintStats =
    const bool.fromEnvironment('global.type.flow.print.stats');

const bool kRemoveAsserts =
    const bool.fromEnvironment('global.type.flow.remove.asserts');

const bool kScopeTrace =
    const bool.fromEnvironment('global.type.flow.scope.trace');

const int kScopeIndent =
    const int.fromEnvironment('global.type.flow.scope.indent', defaultValue: 1);

/// Extended 'assert': always checks condition.
assertx(bool cond, {details}) {
  if (!cond) {
    throw 'Assertion failed.' + (details != null ? ' Details: $details' : '');
  }
}

abstract class _Logger {
  log(Object message, [int scopeChange = 0]);
}

class _ScopedLogger implements _Logger {
  static const String _scopeDelimiter = "┃";
  static const String _reset = "\u001b[0m";
  static const List<String> _colors = [
    "\u001b[37m", // black
    "\u001b[31m", // red
    "\u001b[32m", // green
    "\u001b[33m", // yellow
    "\u001b[34m", // blue
    "\u001b[35m", // magenta
    "\u001b[36m", // cyan
  ];
  static const int _scopeIndent = kScopeIndent;

  int _scope = 0;
  List<String> _scopePrefixes = <String>[""];

  _print(Object message) {
    print(_scopePrefixes[_scope] +
        message.toString().replaceAll("\n", "\n" + _scopePrefixes[_scope]));
  }

  log(Object message, [int scopeChange = 0]) {
    if (scopeChange > 0) _print(message);
    _scope += scopeChange;
    while (_scopePrefixes.length < _scope + 1) {
      final start = _scopePrefixes[_scopePrefixes.length - 1];
      final column = _colors[(_scope + 1) % _colors.length] +
          _scopeDelimiter +
          _reset +
          " " * _scopeIndent;
      _scopePrefixes.add(start + column);
    }
    if (scopeChange <= 0) _print(message);
  }
}

class _SimpleLogger implements _Logger {
  log(Object message, [int scopeChange = 0]) => print(message);
}

_Logger _logger = kScopeTrace ? _ScopedLogger() : _SimpleLogger();

tracePrint(Object message, [int scopeChange = 0]) {
  if (kPrintTrace) {
    _logger.log(message, scopeChange);
  }
}

debugPrint(Object message) {
  if (kPrintDebug) {
    _logger.log(message);
  }
}

statPrint(Object message) {
  if (kPrintStats) {
    _logger.log(message);
  }
}

const int kHashMask = 0x3fffffff;

bool hasReceiverArg(Member member) =>
    member.isInstanceMember || (member is Constructor);

// Type arguments to procedures is only supported for factory constructors of
// generic classes at the moment.
//
// TODO(sjindel/tfa): Extend suport to normal generic functions.
int numTypeParams(Member member) => member is Procedure && member.isFactory
    ? member.function.typeParameters.length
    : 0;

/// Returns true if elements in [list] are in strictly increasing order.
/// List with duplicates is considered not sorted.
bool isSorted(List list) {
  for (int i = 0; i < list.length - 1; i++) {
    if (list[i].compareTo(list[i + 1]) >= 0) {
      return false;
    }
  }
  return true;
}

VariableDeclaration findNamedParameter(FunctionNode function, String name) {
  return function.namedParameters
      .firstWhere((p) => p.name == name, orElse: () => null);
}

/// Holds various statistic counters for type flow analysis.
class Statistics {
  static int summariesCreated = 0;
  static int summariesAnalyzed = 0;
  static int joinsApproximatedToBreakLoops = 0;
  static int invocationsProcessed = 0;
  static int usedCachedResultsOfInvocations = 0;
  static int invocationsInvalidated = 0;
  static int maxInvalidationsPerInvocation = 0;
  static int recursiveInvocationsApproximated = 0;
  static int typeConeSpecializations = 0;
  static int iterationsOverInvocationsWorkList = 0;
  static int invocationsInvalidatedDuringProcessing = 0;
  static int invocationsQueriedInCache = 0;
  static int invocationsAddedToCache = 0;
  static int maxInvocationsCachedPerSelector = 0;
  static int approximateInvocationsCreated = 0;
  static int approximateInvocationsUsed = 0;
  static int classesDropped = 0;
  static int membersDropped = 0;
  static int methodBodiesDropped = 0;
  static int fieldInitializersDropped = 0;
  static int constructorBodiesDropped = 0;
  static int callsDropped = 0;
  static int throwExpressionsPruned = 0;

  /// Resets statistic counters.
  static void reset() {
    summariesCreated = 0;
    summariesAnalyzed = 0;
    joinsApproximatedToBreakLoops = 0;
    invocationsProcessed = 0;
    usedCachedResultsOfInvocations = 0;
    invocationsInvalidated = 0;
    maxInvalidationsPerInvocation = 0;
    recursiveInvocationsApproximated = 0;
    typeConeSpecializations = 0;
    iterationsOverInvocationsWorkList = 0;
    invocationsInvalidatedDuringProcessing = 0;
    invocationsQueriedInCache = 0;
    invocationsAddedToCache = 0;
    maxInvocationsCachedPerSelector = 0;
    approximateInvocationsCreated = 0;
    approximateInvocationsUsed = 0;
    classesDropped = 0;
    membersDropped = 0;
    methodBodiesDropped = 0;
    fieldInitializersDropped = 0;
    constructorBodiesDropped = 0;
    callsDropped = 0;
    throwExpressionsPruned = 0;
  }

  static void print(String caption) {
    statPrint("""${caption}:
    ${summariesCreated} summaries created
    ${summariesAnalyzed} summaries analyzed
    ${joinsApproximatedToBreakLoops} joins are approximated to break loops
    ${invocationsProcessed} invocations processed
    ${usedCachedResultsOfInvocations} times cached result of invocation is used
    ${invocationsInvalidated} invocations invalidated
    ${maxInvalidationsPerInvocation} maximum invalidations per invocation
    ${recursiveInvocationsApproximated} recursive invocations approximated
    ${typeConeSpecializations} type cones specialized
    ${iterationsOverInvocationsWorkList} iterations over invocations work list
    ${invocationsInvalidatedDuringProcessing} invocations invalidated during processing
    ${invocationsQueriedInCache} invocations queried in cache
    ${invocationsAddedToCache} invocations added to cache
    ${maxInvocationsCachedPerSelector} maximum invocations cached per selector
    ${approximateInvocationsCreated} approximate invocations created
    ${approximateInvocationsUsed} times approximate invocation is used
    ${classesDropped} classes dropped
    ${membersDropped} members dropped
    ${methodBodiesDropped} method bodies dropped
    ${fieldInitializersDropped} field initializers dropped
    ${constructorBodiesDropped} constructor bodies dropped
    ${callsDropped} calls dropped
    ${throwExpressionsPruned} throw expressions pruned
    """);
  }
}

int typeArgumentsHash(List<DartType> typeArgs) {
  int hash = 1237;
  for (var t in typeArgs) {
    hash = (((hash * 31) & kHashMask) + t.hashCode) & kHashMask;
  }
  return hash;
}

class SubtypePair {
  final Class subtype;
  final Class supertype;

  SubtypePair(this.subtype, this.supertype);

  int get hashCode {
    return subtype.hashCode ^ supertype.hashCode;
  }

  bool operator ==(Object other) {
    if (other is SubtypePair) {
      return subtype == other.subtype && supertype == other.supertype;
    }
    return false;
  }
}

// Returns the smallest index 'i' such that 'list.skip(i)' is a prefix of
// 'sublist'.
int findOverlap(List list, List sublist) {
  for (int i = 0; i < list.length; ++i)
    outer:
    {
      for (int j = 0; j < sublist.length && i + j < list.length; ++j) {
        if (list[i + j] != sublist[j]) continue outer;
      }
      return i;
    }
  return list.length;
}

const nullabilitySuffix = {
  Nullability.legacy: '*',
  Nullability.nullable: '?',
  Nullability.undetermined: '',
  Nullability.nonNullable: '',
};

extension NullabilitySuffix on Nullability {
  String get suffix => nullabilitySuffix[this];
}
