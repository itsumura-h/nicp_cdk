import Blob "mo:base/Blob";
import Text "mo:base/Text";

persistent actor {
  public query func responseNull() : async Null {
    return null;
  };

  public query func responseEmpty() : async () {
    return ();
  };

  public query func boolFunc() : async Bool {
    return true;
  };

  public query func intFunc() : async Int {
    return 1;
  };

  public query func int8Func() : async Int8 {
    return 1;
  };

  public query func int16Func() : async Int16 {
    return 1;
  };

  public query func int32Func() : async Int32 {
    return 1;
  };

  public query func int64Func() : async Int64 {
    return 1;
  };

  public query func natFunc() : async Nat {
    return 1;
  };

  public query func nat8Func() : async Nat8 {
    return 1;
  };

  public query func nat16Func() : async Nat16 {
    return 1;
  };

  public query func nat32Func() : async Nat32 {
    return 1;
  };

  public query func nat64Func() : async Nat64 {
    return 1;
  };

  public query func floatFunc() : async Float {
    return 1.0;
  };

  public query func textFunc() : async Text {
    return "Hello, World!";
  };

  public query func blobFunc() : async Blob {
    return Text.encodeUtf8("Hello, World!");
  };

  public query func vecNatFunc() : async [Nat] {
    return [1, 2, 3, 4, 5];
  };

  public query func vecTextFunc() : async [Text] {
    return ["Hello", "World", "Candid", "Vector"];
  };

  public query func vecBoolFunc() : async [Bool] {
    return [true, false, true, false];
  };

  public query func vecIntFunc() : async [Int] {
    return [1, -2, 3, -4, 5];
  };

  public query func vecVecNatFunc() : async [[Nat]] {
    return [[1, 2], [3, 4, 5]];
  };

  public query func vecVecTextFunc() : async [[Text]] {
    return [["Hello", "World"], ["Candid", "Vector"]];
  };

  public query func vecVecBoolFunc() : async [[Bool]] {
    return [[true, false], [false, true]];
  };

  public query func vecVecIntFunc() : async [[Int]] {
    return [[1, -2], [3, -4, 5]];
  };


};
