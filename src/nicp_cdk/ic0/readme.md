[ic0.txt](https://github.com/dfinity/cdk-rs/blob/main/ic0/ic0.txt)  
[ic0.h](https://github.com/icppWorld/icpp-pro/blob/main/src/icpp/ic/ic0/ic0.h)  

AI指示

```
/application/src/nim_ic_cdk/ic0/ic0.txt をパースしてNimの関数定義ファイルに変換してください。

/application/src/nim_ic_cdk/ic0/ic0.nimを作成してください。
Iはintに、i32はuint32に、i64はuint64に変換してください。

例えば `ic0.msg_arg_data_size : () -> I` は`proc ic0_msg_arg_data_size*(): int {.header:"ic0.h", importc.}` に変換してください。
```
