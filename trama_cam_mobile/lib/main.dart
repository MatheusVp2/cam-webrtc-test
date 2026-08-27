/// trama-cam — etapa 1: mandar o vídeo do celular para uma janela no PC.
library;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TramaCamApp());
}

class TramaCamApp extends StatelessWidget {
  const TramaCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'trama-cam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const TelaPrincipal(),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final CamSession _sessao = CamSession();
  final TextEditingController _campoIp = TextEditingController();
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    _sessao.addListener(_aoMudarSessao);
    _sessao.inicializar().then((_) {
      if (mounted) setState(() => _pronto = true);
    });
  }

  void _aoMudarSessao() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sessao.removeListener(_aoMudarSessao);
    _sessao.dispose();
    _campoIp.dispose();
    super.dispose();
  }

  void _aoApertarBotao() {
    if (_sessao.ocupado) {
      _sessao.desconectar();
      return;
    }
    final host = _campoIp.text.trim();
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o IP que apareceu no terminal do PC')),
      );
      return;
    }
    _sessao.conectar(host);
  }

  @override
  Widget build(BuildContext context) {
    if (!_pronto) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('trama-cam'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _ChipDeEstado(estado: _sessao.estado)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _Preview(sessao: _sessao)),
          if (_sessao.mensagemDeErro != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade900,
              padding: const EdgeInsets.all(12),
              child: Text(_sessao.mensagemDeErro!),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _campoIp,
                    enabled: !_sessao.ocupado,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'IP do PC',
                      hintText: '192.168.0.10',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _aoApertarBotao(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _aoApertarBotao,
                  child: Text(_sessao.ocupado ? 'Desconectar' : 'Conectar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview local da câmera, ou uma dica quando ela ainda não ligou.
class _Preview extends StatelessWidget {
  const _Preview({required this.sessao});

  final CamSession sessao;

  @override
  Widget build(BuildContext context) {
    final temVideo = sessao.previewLocal.srcObject != null;

    return Container(
      color: Colors.black,
      width: double.infinity,
      child: temVideo
          ? RTCVideoView(
              sessao.previewLocal,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Rode o desk edge no PC, digite o IP que ele mostrar '
                  'e toque em Conectar.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}

/// Bolinha colorida + texto com o estado atual da conexão.
class _ChipDeEstado extends StatelessWidget {
  const _ChipDeEstado({required this.estado});

  final EstadoDaSessao estado;

  Color get _cor => switch (estado) {
    EstadoDaSessao.aoVivo => Colors.green,
    EstadoDaSessao.erro => Colors.red,
    EstadoDaSessao.desconectado => Colors.grey,
    _ => Colors.amber,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: _cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(estado.rotulo, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
