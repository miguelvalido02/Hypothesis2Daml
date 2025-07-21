/**
 * @file typeMappings.js
 * @description Provides functions for mapping Solidity types to Haskell types.
 */

/**
 * Maps a Solidity TypeName node to an approximate Haskell type.
 * 
 * @function solidityTypeToHaskellType
 * @param {Object} typeNode - The AST node representing a Solidity type.
 * @param {string} [contractName=''] - The name of the contract (used for user-defined types).
 * @returns {string} The corresponding Haskell type as a string. Defaults to 'UnknownType' if no mapping is found.
 * 
 * @example
 * // For a node representing 'uint256', it returns 'Integer'.
 * // For a node representing 'bool', it returns 'Bool'.
 * // For a node representing 'string', it returns 'String'.
 */
function solidityTypeToHaskellType(typeNode, contractName='') {
  if (!typeNode) return 'UnknownType';

  switch (typeNode.type) {
    case 'ElementaryTypeName': {
      // Examples include 'uint256', 'bool', 'string', etc.
      const name = typeNode.name;
      if (name.startsWith('uint')) {
        return 'Uint';
      } else if (name.startsWith('int')) {
        return 'Integer';
      } else if (name === 'bool') {
        return 'Bool';
      } else if (name === 'string') {
        return 'String';
      } else if (name === 'address') {
        return 'Address';
      }
      return `UnknownType_${name}`;
    }
    case 'UserDefinedTypeName': {
      // For user-defined types (e.g., enums), return the type name directly.
      return typeNode.namePath ? typeNode.namePath + contractName  : 'UnknownType';
    }
    default:
      return 'UnknownType';
  }
}

/**
 * A predefined Haskell `Message` data type and an `Address` type alias for use in generated code.
 * 
 * @constant MSG_DEFINITION
 * @type {string}
 * @example
 */
const MSG_DEFINITION = `import Data.Char (ord)

foldl' f z []     = z
foldl' f z (x:xs) = let z' = z \`f\` x 
                    in seq z' $ foldl' f z' xs

{-@ fromString :: String -> {v:Integer | v >= 0} @-}
fromString :: String -> Integer
fromString = foldl' (\\acc c -> let acc' = acc * 31 + toInteger (ord c) in
                               if acc' >= 0 then acc' else 0) 0
data Message = Message {
  sender :: Address,
  value :: Integer
} deriving (Show, Eq)

{-@ data Message = Message {
  sender :: Address,
  value :: Integer}
@-}

data Block = Block {
  number :: Integer}

{-@ data Block = Block {
  number :: Integer}
@-}

{-@ type Amount = {v: Integer | v >= 0} @-}
type Amount = Integer

{-@ type Uint = {v: Integer | v >= 0} @-}
type Uint = Integer

type Address = Integer
{-@ type Address = Integer @-}`;

module.exports = {
  solidityTypeToHaskellType,
  MSG_DEFINITION
};