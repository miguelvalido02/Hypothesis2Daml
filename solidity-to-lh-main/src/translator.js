/**
 * @file translator.js
 * @description Contains helper functions to translate Solidity AST nodes into Haskell equivalents.
 */
const { normalizeVariableName } = require('./gatherState');
/**
 * Translates a Solidity expression AST node into a Haskell expression string.
 * 
 * @function translateExpression
 * @param {Object} expr - The AST node representing a Solidity expression.
 * @param {Array<{ name: string, type: string }>} params - An array of function parameter information.
 * @param {Object} stateInfo - An object containing state variable and enum definitions.
 * @returns {string} A string representing the translated Haskell expression.
 * 
 * @example
 * // For a Solidity expression "x + 1":
 * // it might return "x + 1" in Haskell.
 */
function translateExpression(expr, params, stateInfo) {
  if (!stateInfo) return 'undefined';
  const state_variables = stateInfo.variables || [];
  if (expr.type === 'FunctionCall' && expr.expression.name === 'revert') {
    const args = expr.arguments || [];
    if (args.length > 0) {
      // revert with message
      const msg = translateExpression(args[0], params, state_variables);
      return `revert ${msg}`;
    }
    // revert without message
    return 'revert "error"';
  }
  if (expr.type === 'FunctionCall' && 
    expr.expression.type === 'NameValueExpression' &&
    expr.expression.expression.type === 'MemberAccess' &&
    expr.expression.expression.memberName === 'call') {

  // Get target address
  const targetAddr = translateExpression(
    expr.expression.expression.expression, 
    params, 
    stateInfo
  );

  // Get balance amount
  let amount = '(balance st)';
  if (expr.expression.arguments?.type === 'NameValueList') {
    const valueArg = expr.expression.arguments.arguments[0];
    if (valueArg.type === 'MemberAccess' && 
        valueArg.memberName === 'balance' &&
        valueArg.expression.type === 'FunctionCall' &&
        valueArg.expression.expression.name === 'address') {
      amount = `(balance${stateInfo.contractName} st)`;
    }
  }

  // Return call expression  
  return `call${stateInfo.contractName} st ${targetAddr} ${amount}`;
}
  // check if its another contract call, check if first letter is capitalized
  if(expr.type === 'FunctionCall' && expr.expression.type && expr.expression.type === 'NewExpression'){
    const args = expr.arguments || [];
    const functionName = expr.expression.typeName.namePath;
    return `${'constructor'+functionName} (msg${stateInfo.contractName} st) (block${stateInfo.contractName} st) ${args.map(arg => translateExpression(arg, params, stateInfo)).join(' ')}`;
  }
  if(expr.type === 'FunctionCall' && expr.expression.type && expr.expression.type === 'Identifier' && expr.expression.name == 'address'){
    const arg = expr.arguments[0];
    if (arg.name === 'this') {
      return `address${stateInfo.contractName} st`;
    }
    else if (arg.type === 'NumberLiteral') {
      return arg.number;
    }
  }
  if (expr.type === 'FunctionCall' && expr.expression.type === 'MemberAccess') {
    const args = expr.arguments || [];
    const memberAccess = expr.expression;
    
    // Check if this is a call on a contract instance
    if (stateInfo.contractInstances && stateInfo.contractInstances[memberAccess.expression.name]) {
      // Use the instance variable name directly
      const instanceName = memberAccess.expression.name;
      const functionName = uncapitalize(memberAccess.memberName);
      
      // Call the function on the instance
      return `${functionName} ${instanceName} ${args.map(arg => 
        translateExpression(arg, params, stateInfo)).join(' ')}`;
    } else {
      // Regular member function call
      const functionName = uncapitalize(memberAccess.memberName);
      return `${functionName} st ${args.map(arg => 
        translateExpression(arg, params, stateInfo)).join(' ')}`;
    }
  }


  if (expr.type === 'BooleanLiteral') {
    return expr.value.toString().charAt(0).toUpperCase() + expr.value.toString().slice(1);
  }
  if (expr.type === 'MemberAccess') {
    if (expr.expression.name === 'msg') {
      if (expr.memberName === 'sender') {
        return `(sender (${"msg"+stateInfo.contractName} st))`;
      }
      if (expr.memberName === 'value') {
        return `(value (${"msg"+stateInfo.contractName} st))`;
      }
    }
    if (expr.memberName === 'balance') {
      return `(balance${stateInfo.contractName} st)`;
    }
    if (expr.expression.name === 'block' && expr.memberName === 'number') {
      return `(number (${"block"+stateInfo.contractName} st))`;
    }
    // Handle enum member access like StateType.Request
    if (expr.expression.name && expr.memberName) {
      // Return just the member name since in Haskell we defined them directly
      return expr.memberName+stateInfo.contractName;
    }
  }
  if (expr.type === 'BinaryOperation') {
    const left = translateExpression(expr.left, params, stateInfo);
    const right = translateExpression(expr.right, params, stateInfo);

    const operator = translateOperator(expr.operator);
    return `(${left} ${operator} ${right})`;
  }
  if (expr.type === 'UnaryOperation') {
    const subExpression = translateExpression(expr.subExpression, params, stateInfo);
    return `(${translateOperator(expr.operator)}(${subExpression}))`;
  }

  const paramMap = new Map(params.map(p => [p.originalName, p.name]));

  if (expr.type === 'Identifier') {
    if (stateInfo.localVars.has(expr.name)) {
      return expr.name; // Return name directly for local vars
    }
    const identifierName = expr.name;
    // Check if it's a parameter first
    if (paramMap.has(identifierName)) {
      return paramMap.get(identifierName);
    }
    // Check state variables comparing their names
    const stateVar = state_variables.find(v => v.originalName === identifierName);
    if (stateVar) {
      return `(${stateVar.name} st)`;
    }


  }
  if (expr.type === 'NumberLiteral') {
    return expr.number;
  }
  if (expr.type === 'StringLiteral') {
    return `"${expr.value}"`;
  }
  if (expr.type === 'TupleExpression') {
    return `${expr.components.map((c) => translateExpression(c, params, stateInfo)).join(', ')}`;
  }

  if(expr.type === 'Conditional') {
    const condition = translateExpression(expr.condition, params, stateInfo);
    const trueExpr = translateExpression(expr.trueExpression, params, stateInfo);
    const falseExpr = translateExpression(expr.falseExpression, params, stateInfo);

    return `if ${condition} then ${trueExpr} else ${falseExpr}`;
  }

  return 'undefined';
}

/**
 * Translates a Solidity statement AST node into a Haskell state transformation expression.
 * 
 * @function translateStatement
 * @param {Object} statement - The AST node for a Solidity statement (e.g., ExpressionStatement).
 * @param {Array<{ name: string, type: string }>} params - An array of function parameter information.
 * @param {Object} stateInfo - An object containing state variable and enum definitions.
 * @returns {string} A string representing the translated Haskell statement.
 * 
 * @example
 * // For "count++":
 * // it might return "st { count = count st + 1 }".
 */
function translateStatement(statement, params, stateInfo, indentLevel = 0) {
  if (statement.type === 'IfStatement') {
    const condition = translateExpression(statement.condition, params, stateInfo);
    const trueBody = translateStatements(statement.trueBody.statements, params, stateInfo, indentLevel);
    const falseBody = statement.falseBody ?
      translateStatements(statement.falseBody.statements, params, stateInfo, indentLevel) :
      'st';

    const code = translateIf(condition, trueBody, falseBody, indentLevel);
    return { code, isLocal: false };
  }

  if (statement.type === 'AssignmentStatement') {
    const varName = statement.variable.name;
    const value = translateExpression(statement.value, params, stateInfo);
    return { code: `st { ${varName} = ${value} }`, isLocal: false };
  }


  if (statement.type === 'Block') {
    const blockCode = translateStatements(statement.statements, params, stateInfo, indentLevel);
    return { code: blockCode, isLocal: false };
  }

  if (statement.type === 'ExpressionStatement') {
    const expr = statement.expression;

    // revert(...)
    if (expr.type === 'FunctionCall' && expr.expression.name === 'revert') {
      return { code: translateExpression(expr, params, stateInfo), isLocal: false };
    }
    // require(...)
    if (expr.type === 'FunctionCall' && expr.expression.name === 'require') {
      const condition = translateExpression(expr.arguments[0], params, stateInfo);
      // to skip the requiere from the the call
      if (condition === 'undefined') {
        return { code: 'st -- skipped require statement', isLocal: false };
      }
      return { code: `if ${condition} then st else revert "error"`, isLocal: false };
    }
    // assert(...)
    if (expr.type === 'FunctionCall' && expr.expression.name === 'assert') {
      // no-op or "if cond then st else revert ..."
      return { code: 'st -- assert statement', isLocal: false };
    }

    if(expr.type === 'FunctionCall' && expr.expression.type === 'Identifier'){
      const functionName = normalizeVariableName(expr.expression.name);
      const args = expr.arguments || [];
      return { code: `${functionName} st ${args.map(arg => translateExpression(arg, params, stateInfo)).join(' ')}`, isLocal: false };
    }

    // x++
    if (expr.type === 'UnaryOperation' && expr.operator === '++') {
      const originalName = expr.subExpression.name;
      const normalizedName = stateInfo.nameMap.get(originalName) || originalName;
      const code = `st { ${normalizedName} = ((${normalizedName} st) + 1) }`;

      return { code: code, isLocal: false };
    }
    if (expr.type === 'BinaryOperation' && expr.operator === '=') {
      const leftSide = expr.left.name;
      const normalizedLeft = stateInfo.nameMap.get(leftSide) || leftSide;
      const rightSide = translateExpression(expr.right, params, stateInfo);
      return { code: `st { ${normalizedLeft} = ${rightSide} }`, isLocal: false };
    }
    if (expr.type === 'BinaryOperation' && (expr.operator === '+=' || expr.operator === '-=')) {
      const leftSide = expr.left.name;
      const normalizedLeft = stateInfo.nameMap.get(leftSide) || leftSide;
      const rightSide = translateExpression(expr.right, params, stateInfo);
      const op = expr.operator === '+=' ? '+' : '-';
      return { code: `st { ${normalizedLeft} = ((${normalizedLeft} st) ${op} ${rightSide}) }`, isLocal: false };
    }
  }
  if (statement.type === 'ReturnStatement') {
    const returnVal = translateExpression(statement.expression, params, stateInfo);
    return { code: returnVal, isLocal: false };
  }
  if (statement.type === 'VariableDeclarationStatement' && statement.initialValue?.type === 'FunctionCall') {
    const initialValue = statement.initialValue;
  
    // Check for call with value
    if (initialValue?.type === 'FunctionCall' && 
        initialValue.expression?.type === 'NameValueExpression' &&
        initialValue.expression.expression?.type === 'MemberAccess' &&
        initialValue.expression.expression.memberName === 'call') {
      
      // Get target address
      const targetAddr = translateExpression(
        initialValue.expression.expression.expression,
        params, 
        stateInfo
      );
  
      // Get value amount from NameValueList
      let amount;
      if (initialValue.expression.arguments?.type === 'NameValueList') {
        const valueArg = initialValue.expression.arguments.arguments[0];
        if (valueArg.type === 'MemberAccess' && 
            valueArg.memberName === 'balance' &&
            valueArg.expression.type === 'FunctionCall' &&
            valueArg.expression.expression.name === 'address') {
          amount = `balance${stateInfo.contractName} st`;
        }
        else{
          amount = translateExpression(valueArg, params, stateInfo);
        }
      }

      return {
        code: `call${stateInfo.contractName} st (${targetAddr}) (${amount})`,
        isLocal: false
      };
    }
  }
  if (statement.type === 'VariableDeclarationStatement') {
    const declaration = statement.variables[0];
    const varName = declaration.name;
    
    // Add to local vars tracking
    stateInfo.localVars.add(varName);

    if (!statement.initialValue) {
      // no initialization
      return { code: `st -- local var ${varName} (no init)`, isLocal: true };
    }
    const initialValue = translateExpression(statement.initialValue, params, stateInfo);
    if(declaration.typeName.type && declaration.typeName.type === 'UserDefinedTypeName'){
    stateInfo.contractInstances[varName] = declaration.typeName.namePath;
    }
    // produce "varName = <expr>"
    return { code: `${varName} = ${initialValue}`, isLocal: true };
  }

  // fallback
  return { code: 'st  -- TODO: Complex expression', isLocal: false };
}

function translateStatements(statements, params, stateInfo, indentLevel = 0, isView = false) {
  if (!statements || statements.length === 0) {
    return isView ? 'False' : `${indent(indentLevel)}st`;
  }

  if (isView) {
    let localVars = [];
    
    // First gather any local variable declarations
    for (let i = 0; i < statements.length; i++) {
      const stmt = statements[i];
      if (stmt.type === 'VariableDeclarationStatement') {
        const varName = stmt.variables[0].name;
        const value = translateExpression(stmt.initialValue, params, stateInfo);
        localVars.push(`${varName} = ${value}`);
        // Add to stateInfo.localVars to track local variables
        stateInfo.localVars.add(varName);
      }
    }

    // Then process the main logic
    for (let i = 0; i < statements.length; i++) {
      const stmt = statements[i];
      
      if (stmt.type === 'IfStatement') {
        // Handle if condition using tracked local vars
        const condition = translateExpression(stmt.condition, params, stateInfo);
        
        // Extract return expression from if body
        const thenReturn = stmt.trueBody.type === 'ReturnStatement' ? 
          translateExpression(stmt.trueBody.expression, params, stateInfo) : 
          translateStatements([stmt.trueBody], params, stateInfo, indentLevel, true);
        
        let result = localVars.length > 0 ?
          `let ${localVars.join('\n    ')} in\n  if ${condition}\nthen ${thenReturn}` :
          `if ${condition}\nthen ${thenReturn}`;
        
        // Handle else or else-if
        if (i < statements.length - 1 && statements[i+1].type === 'IfStatement') {
          const nextStmt = translateStatements(statements.slice(i+1), params, stateInfo, indentLevel, true);
          return `${result}\nelse ${nextStmt}`;
        } else if (i === statements.length - 2 && statements[i+1].type === 'ReturnStatement') {
          const elseReturn = translateExpression(statements[i+1].expression, params, stateInfo);
          return `${result}\nelse ${elseReturn}`;
        }
        
        return result;
      } else if (stmt.type === 'ReturnStatement') {
        const returnExpr = translateExpression(stmt.expression, params, stateInfo);
        return localVars.length > 0 ?
          `let ${localVars.join('\n    ')} in\n  ${returnExpr}` :
          returnExpr;
      } else if (stmt.type === 'Block') {
        return translateStatements(stmt.statements, params, stateInfo, indentLevel, true);
      }
    }
  }
  else{
  let lines = [];
  let currentState = 'st';
  let nextStateIndex = 1;

  for (let i = 0; i < statements.length; i++) {
    const { code, isLocal } = translateStatement(statements[i], params, stateInfo, indentLevel);
    
    if (isLocal) {
      lines.push(code);
    } else {
      const stNext = `st${nextStateIndex}`;
      const replacedCode = code.replace(/\bst\b/g, currentState);

      lines.push(`${stNext} = ${replacedCode}`);
      currentState = stNext;
      nextStateIndex++;
    }
  }

  const finalState = currentState;

  return translateLet(lines, finalState, indentLevel);
}

}

// Devuelve '  ' (dos espacios) repetidos `level` veces
function indent(level) {
  return '  '.repeat(level);
}

// Ident each line in `lines` with `level` spaces
function withIndent(lines, level) {
  // onyl split if it's a string
  if (typeof lines === 'string') {
    lines = lines.split('\n');
  }
  return lines.map(line => indent(level) + line).join('\n');
}

function translateIf(condition, trueBody, falseBody, indentLevel) {
  // Format bodies with proper nesting
  const formattedTrueBody = trueBody.includes('\n') 
    ? '\n' + withIndent(trueBody.trim(), indentLevel + 2)
    : ' ' + trueBody;
    
  const formattedFalseBody = falseBody.includes('\n')
    ? '\n' + withIndent(falseBody.trim(), indentLevel + 2)
    : ' ' + falseBody;

  return [
    `${indent(indentLevel)}if ${condition}`,
    `${indent(indentLevel+2)}then${formattedTrueBody}`,
    `${indent(indentLevel+2)}else${formattedFalseBody}`
  ].join('\n');
}

function translateLet(bindings, body, indentLevel) {
  const letBlock = [
    `${indent(indentLevel)}let`,
    withIndent(bindings, indentLevel + 1),
    `${indent(indentLevel + 2)}in`,
    `${indent(indentLevel + 3)}${body}`
  ];

  return letBlock.join('\n');
}


/**
 * Translates Solidity operators to their Haskell/Liquid equivalent
 * @param {string} operator - The Solidity operator
 * @returns {string} The equivalent Haskell/Liquid operator
 */
function translateOperator(operator) {
  const operatorMap = {
    // Comparison operators
    '!=': '/=',
    '==': '==',
    '<': '<',
    '<=': '<=',
    '>': '>',
    '>=': '>=',
    
    // Arithmetic operators  
    '+': '+',
    '-': '-',
    '*': '*',
    '/': '/',
    
    // Logical operators
    '&&': '&&',
    '||': '||',
    '!': 'not'
  };

  return operatorMap[operator] || operator;
}

function uncapitalize(str) {
  return str.charAt(0).toLowerCase() + str.slice(1);
}

module.exports = {
  translateExpression,
  translateStatement,
  translateStatements,
  translateOperator,
};
