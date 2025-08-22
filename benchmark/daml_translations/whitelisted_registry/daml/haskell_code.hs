module WhitelistedRegistry where
import (implicit) qualified DA.Internal.Record
import (implicit) qualified GHC.Types
import (implicit) qualified DA.Internal.Desugar
import (implicit) DA.Internal.RebindableSyntax
data GHC.Types.DamlTemplate => WhitelistedRegistry
  = WhitelistedRegistry {owner : Party, whitelisted : [Party]}
  deriving (DA.Internal.Desugar.Eq, DA.Internal.Desugar.Show)
instance DA.Internal.Record.GetField "owner" WhitelistedRegistry Party where
  getField
    = DA.Internal.Record.getFieldPrim
        @"owner" @WhitelistedRegistry @Party
instance DA.Internal.Record.SetField "owner" WhitelistedRegistry Party where
  setField
    = DA.Internal.Record.setFieldPrim
        @"owner" @WhitelistedRegistry @Party
instance DA.Internal.Record.GetField "whitelisted" WhitelistedRegistry [Party] where
  getField
    = DA.Internal.Record.getFieldPrim
        @"whitelisted" @WhitelistedRegistry @[Party]
instance DA.Internal.Record.SetField "whitelisted" WhitelistedRegistry [Party] where
  setField
    = DA.Internal.Record.setFieldPrim
        @"whitelisted" @WhitelistedRegistry @[Party]
data ChangeOwner
  = ChangeOwner {newOwner : Party}
  deriving (DA.Internal.Desugar.Eq, DA.Internal.Desugar.Show)
instance DA.Internal.Record.GetField "newOwner" ChangeOwner Party where
  getField
    = DA.Internal.Record.getFieldPrim @"newOwner" @ChangeOwner @Party
instance DA.Internal.Record.SetField "newOwner" ChangeOwner Party where
  setField
    = DA.Internal.Record.setFieldPrim @"newOwner" @ChangeOwner @Party
data SetWhitelisted
  = SetWhitelisted {addr : Party, isWhitelisted : Bool}
  deriving (DA.Internal.Desugar.Eq, DA.Internal.Desugar.Show)
instance DA.Internal.Record.GetField "addr" SetWhitelisted Party where
  getField
    = DA.Internal.Record.getFieldPrim @"addr" @SetWhitelisted @Party
instance DA.Internal.Record.SetField "addr" SetWhitelisted Party where
  setField
    = DA.Internal.Record.setFieldPrim @"addr" @SetWhitelisted @Party
instance DA.Internal.Record.GetField "isWhitelisted" SetWhitelisted Bool where
  getField
    = DA.Internal.Record.getFieldPrim
        @"isWhitelisted" @SetWhitelisted @Bool
instance DA.Internal.Record.SetField "isWhitelisted" SetWhitelisted Bool where
  setField
    = DA.Internal.Record.setFieldPrim
        @"isWhitelisted" @SetWhitelisted @Bool
data IsWhitelisted
  = IsWhitelisted {addr : Party, caller : Party}
  deriving (DA.Internal.Desugar.Eq, DA.Internal.Desugar.Show)
instance DA.Internal.Record.GetField "addr" IsWhitelisted Party where
  getField
    = DA.Internal.Record.getFieldPrim @"addr" @IsWhitelisted @Party
instance DA.Internal.Record.SetField "addr" IsWhitelisted Party where
  setField
    = DA.Internal.Record.setFieldPrim @"addr" @IsWhitelisted @Party
instance DA.Internal.Record.GetField "caller" IsWhitelisted Party where
  getField
    = DA.Internal.Record.getFieldPrim @"caller" @IsWhitelisted @Party
instance DA.Internal.Record.SetField "caller" IsWhitelisted Party where
  setField
    = DA.Internal.Record.setFieldPrim @"caller" @IsWhitelisted @Party
instance DA.Internal.Desugar.HasSignatory WhitelistedRegistry where
  signatory this@WhitelistedRegistry {..}
    = DA.Internal.Desugar.toParties (owner)
    where
        _ = this
instance DA.Internal.Desugar.HasObserver WhitelistedRegistry where
  observer this@WhitelistedRegistry {..}
    = DA.Internal.Desugar.toParties (whitelisted)
    where
        _ = this
instance DA.Internal.Desugar.HasEnsure WhitelistedRegistry where
  ensure this@WhitelistedRegistry {..}
    = DA.Internal.Desugar.True
    where
        _ = this
instance DA.Internal.Desugar.HasArchive WhitelistedRegistry where
  archive cid
    = DA.Internal.Desugar.exercise cid DA.Internal.Desugar.Archive
    where
        _ = cid
instance DA.Internal.Desugar.HasCreate WhitelistedRegistry where
  create = GHC.Types.primitive @"UCreate"
instance DA.Internal.Desugar.HasFetch WhitelistedRegistry where
  fetch = GHC.Types.primitive @"UFetch"
instance DA.Internal.Desugar.HasToAnyTemplate WhitelistedRegistry where
  _toAnyTemplate = GHC.Types.primitive @"EToAnyTemplate"
instance DA.Internal.Desugar.HasFromAnyTemplate WhitelistedRegistry where
  _fromAnyTemplate = GHC.Types.primitive @"EFromAnyTemplate"
instance DA.Internal.Desugar.HasTemplateTypeRep WhitelistedRegistry where
  _templateTypeRep = GHC.Types.primitive @"ETemplateTypeRep"
instance DA.Internal.Desugar.HasIsInterfaceType WhitelistedRegistry where
  _isInterfaceType _ = DA.Internal.Desugar.False
instance DA.Internal.Desugar.HasExercise WhitelistedRegistry DA.Internal.Desugar.Archive (()) where
  exercise = GHC.Types.primitive @"UExercise"
instance DA.Internal.Desugar.HasToAnyChoice WhitelistedRegistry DA.Internal.Desugar.Archive (()) where
  _toAnyChoice = GHC.Types.primitive @"EToAnyChoice"
instance DA.Internal.Desugar.HasFromAnyChoice WhitelistedRegistry DA.Internal.Desugar.Archive (()) where
  _fromAnyChoice = GHC.Types.primitive @"EFromAnyChoice"
instance DA.Internal.Desugar.HasChoiceController WhitelistedRegistry DA.Internal.Desugar.Archive where
  _choiceController = GHC.Types.primitive @"EChoiceController"
instance DA.Internal.Desugar.HasChoiceObserver WhitelistedRegistry DA.Internal.Desugar.Archive where
  _choiceObserver = GHC.Types.primitive @"EChoiceObserver"
instance DA.Internal.Desugar.HasExercise WhitelistedRegistry ChangeOwner (ContractId WhitelistedRegistry) where
  exercise = GHC.Types.primitive @"UExercise"
instance DA.Internal.Desugar.HasToAnyChoice WhitelistedRegistry ChangeOwner (ContractId WhitelistedRegistry) where
  _toAnyChoice = GHC.Types.primitive @"EToAnyChoice"
instance DA.Internal.Desugar.HasFromAnyChoice WhitelistedRegistry ChangeOwner (ContractId WhitelistedRegistry) where
  _fromAnyChoice = GHC.Types.primitive @"EFromAnyChoice"
instance DA.Internal.Desugar.HasChoiceController WhitelistedRegistry ChangeOwner where
  _choiceController = GHC.Types.primitive @"EChoiceController"
instance DA.Internal.Desugar.HasChoiceObserver WhitelistedRegistry ChangeOwner where
  _choiceObserver = GHC.Types.primitive @"EChoiceObserver"
instance DA.Internal.Desugar.HasExercise WhitelistedRegistry SetWhitelisted (ContractId WhitelistedRegistry) where
  exercise = GHC.Types.primitive @"UExercise"
instance DA.Internal.Desugar.HasToAnyChoice WhitelistedRegistry SetWhitelisted (ContractId WhitelistedRegistry) where
  _toAnyChoice = GHC.Types.primitive @"EToAnyChoice"
instance DA.Internal.Desugar.HasFromAnyChoice WhitelistedRegistry SetWhitelisted (ContractId WhitelistedRegistry) where
  _fromAnyChoice = GHC.Types.primitive @"EFromAnyChoice"
instance DA.Internal.Desugar.HasChoiceController WhitelistedRegistry SetWhitelisted where
  _choiceController = GHC.Types.primitive @"EChoiceController"
instance DA.Internal.Desugar.HasChoiceObserver WhitelistedRegistry SetWhitelisted where
  _choiceObserver = GHC.Types.primitive @"EChoiceObserver"
instance DA.Internal.Desugar.HasExercise WhitelistedRegistry IsWhitelisted (Bool) where
  exercise = GHC.Types.primitive @"UExercise"
instance DA.Internal.Desugar.HasToAnyChoice WhitelistedRegistry IsWhitelisted (Bool) where
  _toAnyChoice = GHC.Types.primitive @"EToAnyChoice"
instance DA.Internal.Desugar.HasFromAnyChoice WhitelistedRegistry IsWhitelisted (Bool) where
  _fromAnyChoice = GHC.Types.primitive @"EFromAnyChoice"
instance DA.Internal.Desugar.HasChoiceController WhitelistedRegistry IsWhitelisted where
  _choiceController = GHC.Types.primitive @"EChoiceController"
instance DA.Internal.Desugar.HasChoiceObserver WhitelistedRegistry IsWhitelisted where
  _choiceObserver = GHC.Types.primitive @"EChoiceObserver"
_choice$_WhitelistedRegistry$Archive :
  (DA.Internal.Desugar.Consuming WhitelistedRegistry,
   WhitelistedRegistry
   -> DA.Internal.Desugar.Archive -> [DA.Internal.Desugar.Party],
   DA.Internal.Desugar.Optional (WhitelistedRegistry
                                 -> DA.Internal.Desugar.Archive -> [DA.Internal.Desugar.Party]),
   DA.Internal.Desugar.Optional (WhitelistedRegistry
                                 -> DA.Internal.Desugar.Archive -> [DA.Internal.Desugar.Party]),
   DA.Internal.Desugar.ContractId WhitelistedRegistry
   -> WhitelistedRegistry
      -> DA.Internal.Desugar.Archive -> DA.Internal.Desugar.Update (()))
_choice$_WhitelistedRegistry$Archive
  = (DA.Internal.Desugar.Consuming, 
     \ this _ -> DA.Internal.Desugar.signatory this, 
     DA.Internal.Desugar.None, DA.Internal.Desugar.None, 
     \ _ _ _ -> pure ())
_choice$_WhitelistedRegistry$ChangeOwner :
  (DA.Internal.Desugar.Consuming WhitelistedRegistry,
   WhitelistedRegistry -> ChangeOwner -> [DA.Internal.Desugar.Party],
   DA.Internal.Desugar.Optional (WhitelistedRegistry
                                 -> ChangeOwner -> [DA.Internal.Desugar.Party]),
   DA.Internal.Desugar.Optional (WhitelistedRegistry
                                 -> ChangeOwner -> [DA.Internal.Desugar.Party]),
   DA.Internal.Desugar.ContractId WhitelistedRegistry
   -> WhitelistedRegistry
      -> ChangeOwner
         -> DA.Internal.Desugar.Update (ContractId WhitelistedRegistry))
_choice$_WhitelistedRegistry$ChangeOwner
  = (DA.Internal.Desugar.Consuming, 
     \ this@WhitelistedRegistry {..}
       -> DA.Internal.Desugar.bypassReduceLambda
            \ arg@ChangeOwner {..}
              -> let _ = this in
                 let _ = arg in DA.Internal.Desugar.toParties (owner), 
     DA.Internal.Desugar.None, DA.Internal.Desugar.None, 
     \ self this@WhitelistedRegistry {..}
       -> DA.Internal.Desugar.bypassReduceLambda
            \ arg@ChangeOwner {..}
              -> let _ = self in
                 let _ = this in let _ = arg in do create this {owner = newOwner})
_choice$_WhitelistedRegistry$SetWhitelisted :
  (DA.Internal.Desugar.Consuming WhitelistedRegistry,
   WhitelistedRegistry
   -> SetWhitelisted -> [DA.Internal.Desugar.Party],
   DA.Internal.Desugar.Optional (WhitelistedRegistry
                                 -> SetWhitelisted -> [DA.Internal.Desugar.Party]),
   DA.Internal.Desugar.Optional (WhitelistedRegistry
                                 -> SetWhitelisted -> [DA.Internal.Desugar.Party]),
   DA.Internal.Desugar.ContractId WhitelistedRegistry
   -> WhitelistedRegistry
      -> SetWhitelisted
         -> DA.Internal.Desugar.Update (ContractId WhitelistedRegistry))
_choice$_WhitelistedRegistry$SetWhitelisted
  = (DA.Internal.Desugar.Consuming, 
     \ this@WhitelistedRegistry {..}
       -> DA.Internal.Desugar.bypassReduceLambda
            \ arg@SetWhitelisted {..}
              -> let _ = this in
                 let _ = arg in DA.Internal.Desugar.toParties (owner), 
     DA.Internal.Desugar.None, DA.Internal.Desugar.None, 
     \ self this@WhitelistedRegistry {..}
       -> DA.Internal.Desugar.bypassReduceLambda
            \ arg@SetWhitelisted {..}
              -> let _ = self in
                 let _ = this in
                 let _ = arg
                 in
                   do let newWhitelist
                            = if isWhitelisted then
                                  addr :: filter (\ p -> p /= addr) whitelisted
                              else
                                  filter (\ p -> p /= addr) whitelisted
                      create this {whitelisted = newWhitelist})
_choice$_WhitelistedRegistry$IsWhitelisted :
  (DA.Internal.Desugar.NonConsuming WhitelistedRegistry,
   WhitelistedRegistry
   -> IsWhitelisted -> [DA.Internal.Desugar.Party],
   DA.Internal.Desugar.Optional (WhitelistedRegistry
                                 -> IsWhitelisted -> [DA.Internal.Desugar.Party]),
   DA.Internal.Desugar.Optional (WhitelistedRegistry
                                 -> IsWhitelisted -> [DA.Internal.Desugar.Party]),
   DA.Internal.Desugar.ContractId WhitelistedRegistry
   -> WhitelistedRegistry
      -> IsWhitelisted -> DA.Internal.Desugar.Update (Bool))
_choice$_WhitelistedRegistry$IsWhitelisted
  = (DA.Internal.Desugar.NonConsuming, 
     \ this@WhitelistedRegistry {..}
       -> DA.Internal.Desugar.bypassReduceLambda
            \ arg@IsWhitelisted {..}
              -> let _ = this in
                 let _ = arg in DA.Internal.Desugar.toParties (caller), 
     DA.Internal.Desugar.None, DA.Internal.Desugar.None, 
     \ self this@WhitelistedRegistry {..}
       -> DA.Internal.Desugar.bypassReduceLambda
            \ arg@IsWhitelisted {..}
              -> let _ = self in
                 let _ = this in let _ = arg in do return (elem addr whitelisted))
