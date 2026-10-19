import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/providers/system_provider.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sys = context.watch<SystemProvider>();
    final logs = sys.history;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Системный лог', style: TextStyle(color: Colors.greenAccent, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Скопировать весь лог',
            icon: const Icon(Icons.copy, color: Colors.greenAccent),
            onPressed: () {
              final allText = logs.join('\n\n');
              Clipboard.setData(ClipboardData(text: allText));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                backgroundColor: Colors.green,
                content: Text('Весь лог скопирован в буфер обмена', style: TextStyle(color: Colors.white)),
              ));
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('Лог пуст', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, i) {
                final log = logs.reversed.toList()[i];
                final isError = log.contains('[ERR]') || log.contains('HTML:');
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SelectableText(
                    log,
                    style: TextStyle(
                      color: isError ? Colors.redAccent : Colors.greenAccent,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
