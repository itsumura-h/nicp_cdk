サンプルリポジトリ
https://github.com/dfinity/examples/tree/master/rust/threshold-ecdsa

https://github.com/dfinity/examples/blob/master/rust/threshold-ecdsa/src/ecdsa_example_rust/src/lib.rs#L27-L41

```rs
#[update]
async fn public_key() -> Result<PublicKeyReply, String> {
    let request = EcdsaPublicKeyArgument {
        canister_id: None,
        derivation_path: vec![],
        key_id: EcdsaKeyIds::TestKeyLocalDevelopment.to_key_id(),
    };

    let (response,) = ecdsa_public_key(request)
        .await
        .map_err(|e| format!("ecdsa_public_key failed {}", e.1))?;

    Ok(PublicKeyReply {
        public_key_hex: hex::encode(response.public_key),
    })
}
```

https://github.com/dfinity/cdk-rs/blob/main/ic-cdk/src/management_canister.rs#L654C14-L661

```rs
/// Gets a SEC1 encoded ECDSA public key for the given canister using the given derivation path.
/// 指定した導出パスを使用して、対象のキャニスターのSEC1エンコード形式のECDSA公開鍵を取得します。
///
/// **Bounded-wait call**
///
/// See [IC method `ecdsa_public_key`](https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-ecdsa_public_key).
pub async fn ecdsa_public_key(arg: &EcdsaPublicKeyArgs) -> CallResult<EcdsaPublicKeyResult> {
    Ok(
        Call::bounded_wait(Principal::management_canister(), "ecdsa_public_key")
            .with_arg(arg)
            .await?
            .candid()?,
    )
}
```

https://github.com/dfinity/cdk-rs/blob/main/ic-cdk/src/call.rs#L166-L177
```rs
pub struct Call<'m, 'a> {
    canister_id: Principal,
    method: &'m str,
    cycles: u128,
    timeout_seconds: Option<u32>,
    encoded_args: Cow<'a, [u8]>,
}

// Constructors
impl<'m> Call<'m, '_> {
    /// Constructs a [`Call`] which will **boundedly** wait for response.
    /// 指定されたキャニスターIDとメソッド名を使用して、応答を待つ [`Call`] を構築します。
    ///
    /// # Note
    ///
    /// The bounded waiting is set with a default 300-second timeout.
    /// It aligns with the `MAX_CALL_TIMEOUT` constant in the current IC implementation.
    /// The timeout can be changed using the [`change_timeout`][Self::change_timeout] method.
    /// To unboundedly wait for response, use the [`Call::unbounded_wait`] constructor instead.
    /// デフォルトでは300秒のタイムアウトが設定されています。
    /// これは現在のIC実装の `MAX_CALL_TIMEOUT` 定数に合致しています。
    /// タイムアウトは [`change_timeout`][Self::change_timeout] メソッドを使用して変更できます。
    /// 応答を待たずに使用するには、[`Call::unbounded_wait`] コンストラクタを使用してください。
    pub fn bounded_wait(canister_id: Principal, method: &'m str) -> Self {
        Self {
            canister_id,
            method,
            cycles: 0,
            // Default to 300-second timeout.
            timeout_seconds: Some(300),
            // Bytes for empty arguments.
            // `candid::Encode!(&()).unwrap()`
            encoded_args: Cow::Owned(vec![0x44, 0x49, 0x44, 0x4c, 0x00, 0x00]),
        }
    }
}
```

https://github.com/dfinity/cdk-rs/blob/main/ic-cdk/src/call.rs#L200-L205
```rs
// Configuration
impl<'a> Call<'_, 'a> {
    /// Sets the argument for the call.
    ///
    /// The argument must implement [`CandidType`].
    pub fn with_arg<A: CandidType>(self, arg: A) -> Self {
        Self {
            encoded_args: Cow::Owned(encode_one(&arg).unwrap_or_else(panic_when_encode_fails)),
            ..self
        }
    }
}
```

https://github.com/dfinity/cdk-rs/blob/main/ic-cdk/src/call.rs#L294-L302
```rs
/// Response of a successful call.
#[derive(Debug)]
pub struct Response(Vec<u8>);

impl Response{
  /// Decodes the response as a single Candid type.
  /// 応答を単一のCandid型としてデコードします。
    pub fn candid<R>(&self) -> Result<R, CandidDecodeFailed>
    where
        R: CandidType + for<'de> Deserialize<'de>,
    {
        decode_one(&self.0).map_err(|e| CandidDecodeFailed {
            type_name: std::any::type_name::<R>().to_string(),
            candid_error: e.to_string(),
        })
    }
}
```
