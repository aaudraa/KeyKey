// libsodium 1.0.22'nin test/default klasöründen otomatik üretildi.
// ignore_for_file: lines_longer_than_80_chars

import 'dart:typed_data';

import 'hex.dart';

final class Argon2idVector {
  const new({
    required this.passwordHex,
    required this.saltHex,
    required this.outLen,
    required this.opsLimit,
    required this.memLimit,
    required this.expectedHex,
  });

  final String passwordHex;
  final String saltHex;
  final int outLen;
  final int opsLimit;
  final int memLimit;
  final String expectedHex;

  Uint8List get salt => fromHex(saltHex);
  Uint8List get expected => fromHex(expectedHex);
  Int8List get password => fromHex(passwordHex).buffer.asInt8List();
}

const argon2idVectors = [
  Argon2idVector(
    passwordHex:
        'a347ae92bce9f80f6f595a4480fc9c2fe7e7d7148d371e9487d75f5c23008ffa'
        'e065577a928febd9b1973a5a95073acdbeb6a030cfc0d79caa2dc5cd011cef02'
        'c08da232d76d52dfbca38ca8dcbd665b17d1665f7cf5fe59772ec909733b24de'
        '97d6f58d220b20c60d7c07ec1fd93c52c31020300c6c1facd77937a597c7a6',
    saltHex: '5541fbc995d5c197ba290346d2c559de',
    outLen: 155,
    opsLimit: 5,
    memLimit: 7256678,
    expectedHex:
        '18acec5d6507739f203d1f5d9f1d862f7c2cdac4f19d2bdff64487e60d969e3c'
        'ed615337b9eec6ac4461c6ca07f0939741e57c24d0005c7ea171a0ee1e734824'
        '9d135b38f222e4dad7b9a033ed83f5ca27277393e316582033c74affe2566a2b'
        'ea47f91f0fd9fe49ece7e1f79f3ad6e9b23e0277c8ecc4b313225748dd2a80f5'
        '679534a0700e246a79a49b3f74eb89ec6205fe1eeb941c73b1fcf1',
  ),
  Argon2idVector(
    passwordHex:
        'e125cee61c8cb7778d9e5ad0a6f5d978ce9f84de213a8556d9ffe202020ab4a6'
        'ed9074a4eb3416f9b168f137510f3a30b70b96cbfa219ff99f6c6eaffb15c06b'
        '60e00cc2890277f0fd3c622115772f7048adaebed86e',
    saltHex: 'f1192dd5dc2368b9cd421338b2243345',
    outLen: 250,
    opsLimit: 4,
    memLimit: 7849083,
    expectedHex:
        '26bab5f101560e48c711da4f05e81f5a3802b7a93d5155b9cab153069cc42b8e'
        '9f910bfead747652a0708d70e4de0bada37218bd203a1201c36b42f9a269b675'
        'b1f30cfc36f35a3030e9c7f57dfba0d341a974c1886f708c3e8297efbfe411bb'
        '9d51375264bd7c70d57a8a56fc9de2c1c97c08776803ec2cd0140bba8e61dc0f'
        '4ad3d3d1a89b4b710af81bfe35a0eea193e18a6da0f5ec05542c9eefc4584458'
        'e1da715611ba09617384748bd43b9bf1f3a6df4ecd091d0875e08d6e2fd8a5c7'
        'ce08904b5160cd38167b76ec76ef2d310049055a564da23d4ebd2b87e421cc33'
        'c401e12d5cd8d936c9baf75ebdfb557d342d2858fc781da31860',
  ),
];

const xchachaKeyHex =
    '808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f';
const xchachaNonceHex = '07000000404142434445464748494a4b4c4d4e4f50515253';
const xchachaAdHex = '50515253c0c1c2c3c4c5c6c7';
const xchachaMessage =
    "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.";
const xchachaCipherTextHex =
    'f8ebea4875044066fc162a0604e171feecfb3d20425248563bcfd5a155dcc47b'
    'bda70b86e5ab9b55002bd1274c02db35321acd7af8b2e2d25015e136b7679458'
    'e9f43243bf719d639badb5feac03f80a19a96ef10cb1d15333a837b90946ba38'
    '54ee74da3f2585efc7e1e170e17e15e563e77601f4f85cafa8e5877614e143e6'
    '8420';
