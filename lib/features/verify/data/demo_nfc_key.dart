/// Khóa RSA demo cho môi trường dev và mock server (Software Design D-17).
/// Khóa thật của production được truyền qua --dart-define-from-file (AppConfig.nfcTransportPublicKey).
const demoPublicKeyJwk = <String, dynamic>{
  'kty': 'RSA',
  'n': 'nKzmbVrdJuVTQq37hvUcvjSMqiCJcZge8RNlcIK0NUAa7jWQy4Eaf6A69W1kfakNby7ge6KTAXwgtt4q9uZ94QJ_9v8Bswns5tGeRh7AOm1fCUieh9hfmNhqqelQ8yj1Q2xQLENzizcKqp4GDqy4x6yYNalvTj3nJ0V_xXeGap4DFKGeeX1XFe8YQROj9pB2Ni5D0GtEXr8h3JSapHkBo1nMzOSld4hWpl6GPY82GAYXA2_SjaFAeNLYeVu3rf81IvaeuPc2vVr8j9kozmrUaI5VFoAFQHq-51B5D894bt2mOVIXGBzh6o-E2VW_BFyQvbAj_uDyGEe90PKqGLcMvw==',
  'e': 'AQAB',
  'kid': 'demo-nfc-key',
  'alg': 'RSA-OAEP-256',
  'key_ops': ['wrapKey'],
};

const demoPrivateKeyJwk = <String, dynamic>{
  'kty': 'RSA',
  'n': 'nKzmbVrdJuVTQq37hvUcvjSMqiCJcZge8RNlcIK0NUAa7jWQy4Eaf6A69W1kfakNby7ge6KTAXwgtt4q9uZ94QJ_9v8Bswns5tGeRh7AOm1fCUieh9hfmNhqqelQ8yj1Q2xQLENzizcKqp4GDqy4x6yYNalvTj3nJ0V_xXeGap4DFKGeeX1XFe8YQROj9pB2Ni5D0GtEXr8h3JSapHkBo1nMzOSld4hWpl6GPY82GAYXA2_SjaFAeNLYeVu3rf81IvaeuPc2vVr8j9kozmrUaI5VFoAFQHq-51B5D894bt2mOVIXGBzh6o-E2VW_BFyQvbAj_uDyGEe90PKqGLcMvw==',
  'e': 'AQAB',
  'd': 'AVfyOenXj6fTyPSY_ZVIg9ELi8Hvq8u0KDkUW5yjUvmTwYswDK60vXdwSf6AKBu1A8kRH75LKG4aEbdiAvADEFTnKAUTzKc_ItOVWeCVoWqir_-xbFTMrRDeCUr46LznLYbWQSrq6Ly2GLR2NNYCV6QBQiSL0c3yF4IfEGBwBKYGyZ__KcXip3DVeZhGsAfhw5wq9ZZYtYUYTCb4gIQ36k56Ylj16Qc31YGf_CsWBjXeDH81PWN6bUE3OLXVHyLNp_uA0cSjxkXBHQNPBulxry1i8EYfLDI9kByolX_1kNmCLA0JFUdGYSMsnlJIYb_ZM-p5qVit-thUfJwhGqF_8Q==',
  'p': '28Ereqbo3CyerncOjOpPUybTn5rogSJjgJ7m3TE7P9x08bvSG0CthG72ljmh5G5iPMWo1N6DgcRjB3TnmePqqYo5-NJPlBjycH_Nz2-mkYxaL4Z5tNrkwAssYFOlEukWSVx4VWWByz0LZMTL1cXfMENt5VpdRE06ihZ_QdSibI0=',
  'q': 'toRMyNMDbnbB4AcsIsBhHdNByMMJddvguUVM32RWKHwCmusbiGW25e3b3szG98p8j17puugvI37ZR3w6zEQxVmYaHn04sqARXilcaasUKRF3gqR-0oePul86ji-ehfOGNszQITaK2Iowa-z0LnfHpdLGiW2ycsrpEK5TpsfnuXs=',
  'kid': 'demo-nfc-key',
  'alg': 'RSA-OAEP-256',
  'key_ops': ['unwrapKey'],
};
