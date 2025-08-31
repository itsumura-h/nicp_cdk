import Blob "mo:base/Blob";
import Text "mo:base/Text";

persistent actor {
  public query func bool() : async Bool {
    return true;
  };

  public query func int() : async Int {
    return 1;
  };

  public query func int8() : async Int8 {
    return 1;
  };

  public query func int16() : async Int16 {
    return 1;
  };

  public query func int32() : async Int32 {
    return 1;
  };

  public query func int64() : async Int64 {
    return 1;
  };

  public query func float64() : async Float {
    return 1.0;
  };

  public query func text() : async Text {
    return "Hello, World!";
  };

  public query func blob() : async Blob {
    return Text.encodeUtf8("Hello, World!");
  };

  public query func responseNull() : async Null {
    return null;
  };

  public query func responseEmpty() : async () {
    return ();
  };
};
