// Teste de fumaça: garante que o app sobe sem estourar exceção.
//
// Não dá para ir além disso aqui: a tela só desenha o formulário depois que o
// `RTCVideoRenderer` inicializa, e isso depende de código nativo que não existe
// no ambiente de teste. A validação de verdade é rodar no celular.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trama_cam_mobile/main.dart';

void main() {
  testWidgets('app sobe e mostra a tela de carregamento', (tester) async {
    await tester.pumpWidget(const TramaCamApp());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
