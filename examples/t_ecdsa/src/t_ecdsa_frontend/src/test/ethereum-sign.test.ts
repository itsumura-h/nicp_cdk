import { describe, test, expect, beforeAll } from 'vitest';
import { verifyMessage, type Hex } from 'viem';
import { createTestActor } from './testHelper';
import type { _SERVICE } from '../../../declarations/t_ecdsa_backend/t_ecdsa_backend.did';

/**
 * Ethereum署名のテスト
 * 
 * このテストは以下のフローを実行します:
 * 1. ICPキャニスターからEthereumウォレットアドレスを取得
 * 2. メッセージに対してキャニスターで署名を実行
 * 3. viemのverifyMessage関数で署名を検証
 */
describe('Ethereum署名とviem検証のテスト', () => {
  let actor: _SERVICE;
  
  beforeAll(async () => {
    // ICPキャニスターへの接続を確立
    actor = await createTestActor();
    await actor.getNewPublicKey();
  });

  test('Ethereumアドレスを取得できること', async () => {
    const address = await actor.getEvmAddress();
    
    // Ethereumアドレスは0xで始まる42文字（0x + 40桁の16進数）
    expect(address).toMatch(/^0x[a-fA-F0-9]{40}$/);
    
    console.log('取得したEthereumアドレス:', address);
  });

  test('メッセージに署名して、viemで検証できること', async () => {
    const message = 'Hello, ICP Ethereum Wallet!';
    
    // Step 1: Ethereumアドレスを取得
    const ethereumAddress = await actor.getEvmAddress();
    expect(ethereumAddress).toMatch(/^0x[a-fA-F0-9]{40}$/);
    console.log('Ethereumアドレス:', ethereumAddress);
    
    // Step 2: ICPキャニスターで署名を実行
    const signature = await actor.signWithEthereum(message);
    expect(signature).toBeTruthy();
    expect(signature).toMatch(/^0x[a-fA-F0-9]{130}$/); // 署名は0x + 130桁の16進数
    console.log('署名:', signature);
    
    // 署名の詳細を出力
    const r = signature.slice(0, 66);
    const s = '0x' + signature.slice(66, 130);
    const v = signature.slice(130, 132);
    console.log('r:', r);
    console.log('s:', s);
    console.log('v:', v, '(decimal:', parseInt(v, 16), ')');
    
    // Step 3: viemのverifyMessage関数で署名を検証
    const isValid = await verifyMessage({
      address: ethereumAddress as Hex,
      message: message,
      signature: signature as Hex,
    });
    
    console.log('署名検証結果:', isValid);
    
    // キャニスター側でも検証してみる
    const canisterIsValid = await actor.verifyWithEthereum({
      message,
      signature,
      ethereumAddress,
    });
    console.log('キャニスター検証結果:', canisterIsValid);
    
    expect(isValid).toBe(true);
  });

  test('複数の異なるメッセージで署名・検証できること', async () => {
    const messages = [
      'First message',
      'Second message with 日本語',
      'Third message with emojis 🚀🌟',
    ];
    
    const ethereumAddress = await actor.getEvmAddress();
    
    for (const message of messages) {
      // 署名実行
      const signature = await actor.signWithEthereum(message);
      
      // viem検証
      const isValid = await verifyMessage({
        address: ethereumAddress as Hex,
        message: message,
        signature: signature as Hex,
      });
      
      expect(isValid).toBe(true);
      console.log(`メッセージ "${message}" の検証: ${isValid}`);
    }
  });

  test('ICPキャニスターのverifyWithEthereum関数でも検証できること', async () => {
    const message = 'Verify with both viem and ICP canister';
    
    // Ethereumアドレスを取得
    const ethereumAddress = await actor.getEvmAddress();
    
    // 署名実行
    const signature = await actor.signWithEthereum(message);
    
    // viem検証
    const viemIsValid = await verifyMessage({
      address: ethereumAddress as Hex,
      message: message,
      signature: signature as Hex,
    });
    expect(viemIsValid).toBe(true);
    
    // ICPキャニスター検証
    const canisterIsValid = await actor.verifyWithEthereum({
      message,
      signature,
      ethereumAddress,
    });
    expect(canisterIsValid).toBe(true);
    
    // 両方の検証結果が一致することを確認
    expect(viemIsValid).toBe(canisterIsValid);
    
    console.log('viem検証:', viemIsValid);
    console.log('キャニスター検証:', canisterIsValid);
  });

  test('異なる署名者の署名は検証に失敗すること', async () => {
    const message = 'Test message';
    const signature = await actor.signWithEthereum(message);
    
    // 別のアドレスで検証を試みる（失敗するはず）
    const fakeAddress = '0x0000000000000000000000000000000000000001';
    
    const isValid = await verifyMessage({
      address: fakeAddress as Hex,
      message: message,
      signature: signature as Hex,
    });
    
    expect(isValid).toBe(false);
    console.log('不正なアドレスでの検証結果:', isValid);
  });

  test('改ざんされたメッセージの検証は失敗すること', async () => {
    const originalMessage = 'Original message';
    const tamperedMessage = 'Tampered message';
    
    const ethereumAddress = await actor.getEvmAddress();
    const signature = await actor.signWithEthereum(originalMessage);
    
    // 改ざんされたメッセージで検証を試みる
    const isValid = await verifyMessage({
      address: ethereumAddress as Hex,
      message: tamperedMessage,
      signature: signature as Hex,
    });
    
    expect(isValid).toBe(false);
    console.log('改ざんされたメッセージの検証結果:', isValid);
  });
});

