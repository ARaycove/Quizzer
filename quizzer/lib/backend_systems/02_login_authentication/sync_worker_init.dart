import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/media_sync_worker.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';

/// Initializes the sync workers for online login.
/// Starts inbound sync worker, waits for first cycle completion,
/// then starts outbound and media sync workers.
Future<void> initializeSyncWorkers() async {
  try {
    // check connection
    
    QuizzerLogger.logMessage('Initializing sync workers...');
    
    // Start inbound sync worker
    QuizzerLogger.logMessage('Starting inbound sync worker...');
    final inboundSyncWorker = InboundSyncWorker();
    inboundSyncWorker.start();
    
    // Wait for inbound sync cycle to complete before starting other workers
    QuizzerLogger.logMessage('Waiting for inbound sync cycle to complete...');
    final switchBoard = SwitchBoard();
    await switchBoard.onInboundSyncCycleComplete.first;
    QuizzerLogger.logSuccess('Inbound sync cycle completed');
    
    // Start outbound sync worker
    QuizzerLogger.logMessage('Starting outbound sync worker...');
    final outboundSyncWorker = OutboundSyncWorker();
    outboundSyncWorker.start();
    
    // Start media sync worker
    QuizzerLogger.logMessage('Starting media sync worker...');
    final mediaSyncWorker = MediaSyncWorker();
    mediaSyncWorker.start();
    
    QuizzerLogger.logSuccess('Sync workers initialized successfully');
  } catch (e) {
    QuizzerLogger.logError('Error initializing sync workers: $e');
    rethrow;
  }
}
