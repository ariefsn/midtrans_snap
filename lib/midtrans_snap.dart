library midtrans_snap;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:midtrans_snap/constants.dart';
import 'package:midtrans_snap/models.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MidtransSnap extends StatelessWidget {
  MidtransSnap(
      {super.key,
      required this.mode,
      required this.token,
      required this.midtransClientKey,
      this.onPageStarted,
      this.onPageFinished,
      this.onResponse,
      this.onNavigationRequest,
      this.onProgress,
      this.onWebResourceError});

  final MidtransEnvironment mode;
  final String token, midtransClientKey;
  final void Function(String url)? onPageStarted, onPageFinished;
  final void Function(MidtransResponse result)? onResponse;
  final void Function(WebResourceError error)? onWebResourceError;
  final void Function(int progress)? onProgress;
  final FutureOr<NavigationDecision> Function(NavigationRequest request)?
      onNavigationRequest;

  static PlatformWebViewControllerCreationParams _getCreationParams() {
    return const PlatformWebViewControllerCreationParams();
  }

  final _controller =
      WebViewController.fromPlatformCreationParams(_getCreationParams())
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000));

  @override
  Widget build(BuildContext context) {
    final isProduction = mode == MidtransEnvironment.production;

    return WebViewWidget(
      controller: _controller
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              onProgress?.call(progress);
            },
            onPageStarted: (String url) {
              onPageStarted?.call(url);
            },
            onPageFinished: (String url) {
              onPageFinished?.call(url);
            },
            onWebResourceError: (WebResourceError error) {
              onWebResourceError?.call(error);
            },
            onNavigationRequest: (NavigationRequest request) {
              if (onNavigationRequest != null) {
                return onNavigationRequest!.call(request);
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..addJavaScriptChannel(
          'Print',
          onMessageReceived: (JavaScriptMessage receiver) {
            if (![null, 'undefined'].contains(receiver.message)) {
              final resultMap = jsonDecode(receiver.message);
              final result = MidtransResponse.fromJson(resultMap as Map);

              onResponse?.call(result);
            }
          },
        )
        ..loadRequest(
          Uri.dataFromString(
            '''<html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script 
          type="text/javascript"
          src="${isProduction ? production : sandbox}"
          data-client-key="$midtransClientKey"
        ></script>
      </head>
      <body onload="setTimeout(function(){pay()}, 1000)">
        <script type="text/javascript">
            function pay() {
                snap.pay('$token', {
                  // Optional
                  onSuccess: function(result) {
                    Print.postMessage(JSON.stringify(result));
                  },
                  // Optional
                  onPending: function(result) {
                    Print.postMessage(JSON.stringify(result));
                  },
                  // Optional
                  onError: function(result) {
                    Print.postMessage(JSON.stringify(result));
                  },
                  onClose: function() {
                    Print.postMessage('{"transaction_status":"close"}');
                  }
                });
            }
        </script>
      </body>
    </html>''',
            mimeType: 'text/html',
            encoding: Encoding.getByName('utf-8'),
          ),
        ),
    );
  }
}
