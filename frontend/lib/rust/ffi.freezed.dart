// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ffi.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DaemonCommand {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DaemonCommand()';
}


}

/// @nodoc
class $DaemonCommandCopyWith<$Res>  {
$DaemonCommandCopyWith(DaemonCommand _, $Res Function(DaemonCommand) __);
}


/// Adds pattern-matching-related methods to [DaemonCommand].
extension DaemonCommandPatterns on DaemonCommand {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DaemonCommand_Init value)?  init,TResult Function( DaemonCommand_StartEngine value)?  startEngine,TResult Function( DaemonCommand_StopEngine value)?  stopEngine,TResult Function( DaemonCommand_SaveMessage value)?  saveMessage,TResult Function( DaemonCommand_GetMessages value)?  getMessages,TResult Function( DaemonCommand_SendFile value)?  sendFile,TResult Function( DaemonCommand_AcceptFile value)?  acceptFile,TResult Function( DaemonCommand_CancelTransfer value)?  cancelTransfer,TResult Function( DaemonCommand_MarkMessagesRead value)?  markMessagesRead,TResult Function( DaemonCommand_RejectFile value)?  rejectFile,TResult Function( DaemonCommand_GenerateCredentials value)?  generateCredentials,TResult Function( DaemonCommand_GenerateQrPayload value)?  generateQrPayload,TResult Function( DaemonCommand_JoinSession value)?  joinSession,TResult Function( DaemonCommand_SetSettings value)?  setSettings,TResult Function( DaemonCommand_GetSettings value)?  getSettings,TResult Function( DaemonCommand_GenerateSessionCode value)?  generateSessionCode,TResult Function( DaemonCommand_JoinSessionCode value)?  joinSessionCode,TResult Function( DaemonCommand_SetDeviceName value)?  setDeviceName,TResult Function( DaemonCommand_StartDiscovery value)?  startDiscovery,TResult Function( DaemonCommand_GenerateCode value)?  generateCode,TResult Function( DaemonCommand_ConnectPeer value)?  connectPeer,TResult Function( DaemonCommand_SendMessage value)?  sendMessage,TResult Function( DaemonCommand_StopDiscovery value)?  stopDiscovery,TResult Function( DaemonCommand_DisconnectPeer value)?  disconnectPeer,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DaemonCommand_Init() when init != null:
return init(_that);case DaemonCommand_StartEngine() when startEngine != null:
return startEngine(_that);case DaemonCommand_StopEngine() when stopEngine != null:
return stopEngine(_that);case DaemonCommand_SaveMessage() when saveMessage != null:
return saveMessage(_that);case DaemonCommand_GetMessages() when getMessages != null:
return getMessages(_that);case DaemonCommand_SendFile() when sendFile != null:
return sendFile(_that);case DaemonCommand_AcceptFile() when acceptFile != null:
return acceptFile(_that);case DaemonCommand_CancelTransfer() when cancelTransfer != null:
return cancelTransfer(_that);case DaemonCommand_MarkMessagesRead() when markMessagesRead != null:
return markMessagesRead(_that);case DaemonCommand_RejectFile() when rejectFile != null:
return rejectFile(_that);case DaemonCommand_GenerateCredentials() when generateCredentials != null:
return generateCredentials(_that);case DaemonCommand_GenerateQrPayload() when generateQrPayload != null:
return generateQrPayload(_that);case DaemonCommand_JoinSession() when joinSession != null:
return joinSession(_that);case DaemonCommand_SetSettings() when setSettings != null:
return setSettings(_that);case DaemonCommand_GetSettings() when getSettings != null:
return getSettings(_that);case DaemonCommand_GenerateSessionCode() when generateSessionCode != null:
return generateSessionCode(_that);case DaemonCommand_JoinSessionCode() when joinSessionCode != null:
return joinSessionCode(_that);case DaemonCommand_SetDeviceName() when setDeviceName != null:
return setDeviceName(_that);case DaemonCommand_StartDiscovery() when startDiscovery != null:
return startDiscovery(_that);case DaemonCommand_GenerateCode() when generateCode != null:
return generateCode(_that);case DaemonCommand_ConnectPeer() when connectPeer != null:
return connectPeer(_that);case DaemonCommand_SendMessage() when sendMessage != null:
return sendMessage(_that);case DaemonCommand_StopDiscovery() when stopDiscovery != null:
return stopDiscovery(_that);case DaemonCommand_DisconnectPeer() when disconnectPeer != null:
return disconnectPeer(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DaemonCommand_Init value)  init,required TResult Function( DaemonCommand_StartEngine value)  startEngine,required TResult Function( DaemonCommand_StopEngine value)  stopEngine,required TResult Function( DaemonCommand_SaveMessage value)  saveMessage,required TResult Function( DaemonCommand_GetMessages value)  getMessages,required TResult Function( DaemonCommand_SendFile value)  sendFile,required TResult Function( DaemonCommand_AcceptFile value)  acceptFile,required TResult Function( DaemonCommand_CancelTransfer value)  cancelTransfer,required TResult Function( DaemonCommand_MarkMessagesRead value)  markMessagesRead,required TResult Function( DaemonCommand_RejectFile value)  rejectFile,required TResult Function( DaemonCommand_GenerateCredentials value)  generateCredentials,required TResult Function( DaemonCommand_GenerateQrPayload value)  generateQrPayload,required TResult Function( DaemonCommand_JoinSession value)  joinSession,required TResult Function( DaemonCommand_SetSettings value)  setSettings,required TResult Function( DaemonCommand_GetSettings value)  getSettings,required TResult Function( DaemonCommand_GenerateSessionCode value)  generateSessionCode,required TResult Function( DaemonCommand_JoinSessionCode value)  joinSessionCode,required TResult Function( DaemonCommand_SetDeviceName value)  setDeviceName,required TResult Function( DaemonCommand_StartDiscovery value)  startDiscovery,required TResult Function( DaemonCommand_GenerateCode value)  generateCode,required TResult Function( DaemonCommand_ConnectPeer value)  connectPeer,required TResult Function( DaemonCommand_SendMessage value)  sendMessage,required TResult Function( DaemonCommand_StopDiscovery value)  stopDiscovery,required TResult Function( DaemonCommand_DisconnectPeer value)  disconnectPeer,}){
final _that = this;
switch (_that) {
case DaemonCommand_Init():
return init(_that);case DaemonCommand_StartEngine():
return startEngine(_that);case DaemonCommand_StopEngine():
return stopEngine(_that);case DaemonCommand_SaveMessage():
return saveMessage(_that);case DaemonCommand_GetMessages():
return getMessages(_that);case DaemonCommand_SendFile():
return sendFile(_that);case DaemonCommand_AcceptFile():
return acceptFile(_that);case DaemonCommand_CancelTransfer():
return cancelTransfer(_that);case DaemonCommand_MarkMessagesRead():
return markMessagesRead(_that);case DaemonCommand_RejectFile():
return rejectFile(_that);case DaemonCommand_GenerateCredentials():
return generateCredentials(_that);case DaemonCommand_GenerateQrPayload():
return generateQrPayload(_that);case DaemonCommand_JoinSession():
return joinSession(_that);case DaemonCommand_SetSettings():
return setSettings(_that);case DaemonCommand_GetSettings():
return getSettings(_that);case DaemonCommand_GenerateSessionCode():
return generateSessionCode(_that);case DaemonCommand_JoinSessionCode():
return joinSessionCode(_that);case DaemonCommand_SetDeviceName():
return setDeviceName(_that);case DaemonCommand_StartDiscovery():
return startDiscovery(_that);case DaemonCommand_GenerateCode():
return generateCode(_that);case DaemonCommand_ConnectPeer():
return connectPeer(_that);case DaemonCommand_SendMessage():
return sendMessage(_that);case DaemonCommand_StopDiscovery():
return stopDiscovery(_that);case DaemonCommand_DisconnectPeer():
return disconnectPeer(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DaemonCommand_Init value)?  init,TResult? Function( DaemonCommand_StartEngine value)?  startEngine,TResult? Function( DaemonCommand_StopEngine value)?  stopEngine,TResult? Function( DaemonCommand_SaveMessage value)?  saveMessage,TResult? Function( DaemonCommand_GetMessages value)?  getMessages,TResult? Function( DaemonCommand_SendFile value)?  sendFile,TResult? Function( DaemonCommand_AcceptFile value)?  acceptFile,TResult? Function( DaemonCommand_CancelTransfer value)?  cancelTransfer,TResult? Function( DaemonCommand_MarkMessagesRead value)?  markMessagesRead,TResult? Function( DaemonCommand_RejectFile value)?  rejectFile,TResult? Function( DaemonCommand_GenerateCredentials value)?  generateCredentials,TResult? Function( DaemonCommand_GenerateQrPayload value)?  generateQrPayload,TResult? Function( DaemonCommand_JoinSession value)?  joinSession,TResult? Function( DaemonCommand_SetSettings value)?  setSettings,TResult? Function( DaemonCommand_GetSettings value)?  getSettings,TResult? Function( DaemonCommand_GenerateSessionCode value)?  generateSessionCode,TResult? Function( DaemonCommand_JoinSessionCode value)?  joinSessionCode,TResult? Function( DaemonCommand_SetDeviceName value)?  setDeviceName,TResult? Function( DaemonCommand_StartDiscovery value)?  startDiscovery,TResult? Function( DaemonCommand_GenerateCode value)?  generateCode,TResult? Function( DaemonCommand_ConnectPeer value)?  connectPeer,TResult? Function( DaemonCommand_SendMessage value)?  sendMessage,TResult? Function( DaemonCommand_StopDiscovery value)?  stopDiscovery,TResult? Function( DaemonCommand_DisconnectPeer value)?  disconnectPeer,}){
final _that = this;
switch (_that) {
case DaemonCommand_Init() when init != null:
return init(_that);case DaemonCommand_StartEngine() when startEngine != null:
return startEngine(_that);case DaemonCommand_StopEngine() when stopEngine != null:
return stopEngine(_that);case DaemonCommand_SaveMessage() when saveMessage != null:
return saveMessage(_that);case DaemonCommand_GetMessages() when getMessages != null:
return getMessages(_that);case DaemonCommand_SendFile() when sendFile != null:
return sendFile(_that);case DaemonCommand_AcceptFile() when acceptFile != null:
return acceptFile(_that);case DaemonCommand_CancelTransfer() when cancelTransfer != null:
return cancelTransfer(_that);case DaemonCommand_MarkMessagesRead() when markMessagesRead != null:
return markMessagesRead(_that);case DaemonCommand_RejectFile() when rejectFile != null:
return rejectFile(_that);case DaemonCommand_GenerateCredentials() when generateCredentials != null:
return generateCredentials(_that);case DaemonCommand_GenerateQrPayload() when generateQrPayload != null:
return generateQrPayload(_that);case DaemonCommand_JoinSession() when joinSession != null:
return joinSession(_that);case DaemonCommand_SetSettings() when setSettings != null:
return setSettings(_that);case DaemonCommand_GetSettings() when getSettings != null:
return getSettings(_that);case DaemonCommand_GenerateSessionCode() when generateSessionCode != null:
return generateSessionCode(_that);case DaemonCommand_JoinSessionCode() when joinSessionCode != null:
return joinSessionCode(_that);case DaemonCommand_SetDeviceName() when setDeviceName != null:
return setDeviceName(_that);case DaemonCommand_StartDiscovery() when startDiscovery != null:
return startDiscovery(_that);case DaemonCommand_GenerateCode() when generateCode != null:
return generateCode(_that);case DaemonCommand_ConnectPeer() when connectPeer != null:
return connectPeer(_that);case DaemonCommand_SendMessage() when sendMessage != null:
return sendMessage(_that);case DaemonCommand_StopDiscovery() when stopDiscovery != null:
return stopDiscovery(_that);case DaemonCommand_DisconnectPeer() when disconnectPeer != null:
return disconnectPeer(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String dataDir)?  init,TResult Function()?  startEngine,TResult Function()?  stopEngine,TResult Function( String message)?  saveMessage,TResult Function( String peerId)?  getMessages,TResult Function( String peerId,  String filePath)?  sendFile,TResult Function( String offerId,  String peerId,  BigInt fileSize,  String destPath)?  acceptFile,TResult Function( String transferId)?  cancelTransfer,TResult Function( String peerId)?  markMessagesRead,TResult Function( String offerId,  String peerId)?  rejectFile,TResult Function()?  generateCredentials,TResult Function()?  generateQrPayload,TResult Function( String pin)?  joinSession,TResult Function( String key,  String text)?  setSettings,TResult Function( String key)?  getSettings,TResult Function()?  generateSessionCode,TResult Function( String text)?  joinSessionCode,TResult Function( String name)?  setDeviceName,TResult Function()?  startDiscovery,TResult Function()?  generateCode,TResult Function( String peerId,  String address,  int port,  String? encryptionKey)?  connectPeer,TResult Function( String peerId,  String text)?  sendMessage,TResult Function()?  stopDiscovery,TResult Function( String peerId)?  disconnectPeer,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DaemonCommand_Init() when init != null:
return init(_that.dataDir);case DaemonCommand_StartEngine() when startEngine != null:
return startEngine();case DaemonCommand_StopEngine() when stopEngine != null:
return stopEngine();case DaemonCommand_SaveMessage() when saveMessage != null:
return saveMessage(_that.message);case DaemonCommand_GetMessages() when getMessages != null:
return getMessages(_that.peerId);case DaemonCommand_SendFile() when sendFile != null:
return sendFile(_that.peerId,_that.filePath);case DaemonCommand_AcceptFile() when acceptFile != null:
return acceptFile(_that.offerId,_that.peerId,_that.fileSize,_that.destPath);case DaemonCommand_CancelTransfer() when cancelTransfer != null:
return cancelTransfer(_that.transferId);case DaemonCommand_MarkMessagesRead() when markMessagesRead != null:
return markMessagesRead(_that.peerId);case DaemonCommand_RejectFile() when rejectFile != null:
return rejectFile(_that.offerId,_that.peerId);case DaemonCommand_GenerateCredentials() when generateCredentials != null:
return generateCredentials();case DaemonCommand_GenerateQrPayload() when generateQrPayload != null:
return generateQrPayload();case DaemonCommand_JoinSession() when joinSession != null:
return joinSession(_that.pin);case DaemonCommand_SetSettings() when setSettings != null:
return setSettings(_that.key,_that.text);case DaemonCommand_GetSettings() when getSettings != null:
return getSettings(_that.key);case DaemonCommand_GenerateSessionCode() when generateSessionCode != null:
return generateSessionCode();case DaemonCommand_JoinSessionCode() when joinSessionCode != null:
return joinSessionCode(_that.text);case DaemonCommand_SetDeviceName() when setDeviceName != null:
return setDeviceName(_that.name);case DaemonCommand_StartDiscovery() when startDiscovery != null:
return startDiscovery();case DaemonCommand_GenerateCode() when generateCode != null:
return generateCode();case DaemonCommand_ConnectPeer() when connectPeer != null:
return connectPeer(_that.peerId,_that.address,_that.port,_that.encryptionKey);case DaemonCommand_SendMessage() when sendMessage != null:
return sendMessage(_that.peerId,_that.text);case DaemonCommand_StopDiscovery() when stopDiscovery != null:
return stopDiscovery();case DaemonCommand_DisconnectPeer() when disconnectPeer != null:
return disconnectPeer(_that.peerId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String dataDir)  init,required TResult Function()  startEngine,required TResult Function()  stopEngine,required TResult Function( String message)  saveMessage,required TResult Function( String peerId)  getMessages,required TResult Function( String peerId,  String filePath)  sendFile,required TResult Function( String offerId,  String peerId,  BigInt fileSize,  String destPath)  acceptFile,required TResult Function( String transferId)  cancelTransfer,required TResult Function( String peerId)  markMessagesRead,required TResult Function( String offerId,  String peerId)  rejectFile,required TResult Function()  generateCredentials,required TResult Function()  generateQrPayload,required TResult Function( String pin)  joinSession,required TResult Function( String key,  String text)  setSettings,required TResult Function( String key)  getSettings,required TResult Function()  generateSessionCode,required TResult Function( String text)  joinSessionCode,required TResult Function( String name)  setDeviceName,required TResult Function()  startDiscovery,required TResult Function()  generateCode,required TResult Function( String peerId,  String address,  int port,  String? encryptionKey)  connectPeer,required TResult Function( String peerId,  String text)  sendMessage,required TResult Function()  stopDiscovery,required TResult Function( String peerId)  disconnectPeer,}) {final _that = this;
switch (_that) {
case DaemonCommand_Init():
return init(_that.dataDir);case DaemonCommand_StartEngine():
return startEngine();case DaemonCommand_StopEngine():
return stopEngine();case DaemonCommand_SaveMessage():
return saveMessage(_that.message);case DaemonCommand_GetMessages():
return getMessages(_that.peerId);case DaemonCommand_SendFile():
return sendFile(_that.peerId,_that.filePath);case DaemonCommand_AcceptFile():
return acceptFile(_that.offerId,_that.peerId,_that.fileSize,_that.destPath);case DaemonCommand_CancelTransfer():
return cancelTransfer(_that.transferId);case DaemonCommand_MarkMessagesRead():
return markMessagesRead(_that.peerId);case DaemonCommand_RejectFile():
return rejectFile(_that.offerId,_that.peerId);case DaemonCommand_GenerateCredentials():
return generateCredentials();case DaemonCommand_GenerateQrPayload():
return generateQrPayload();case DaemonCommand_JoinSession():
return joinSession(_that.pin);case DaemonCommand_SetSettings():
return setSettings(_that.key,_that.text);case DaemonCommand_GetSettings():
return getSettings(_that.key);case DaemonCommand_GenerateSessionCode():
return generateSessionCode();case DaemonCommand_JoinSessionCode():
return joinSessionCode(_that.text);case DaemonCommand_SetDeviceName():
return setDeviceName(_that.name);case DaemonCommand_StartDiscovery():
return startDiscovery();case DaemonCommand_GenerateCode():
return generateCode();case DaemonCommand_ConnectPeer():
return connectPeer(_that.peerId,_that.address,_that.port,_that.encryptionKey);case DaemonCommand_SendMessage():
return sendMessage(_that.peerId,_that.text);case DaemonCommand_StopDiscovery():
return stopDiscovery();case DaemonCommand_DisconnectPeer():
return disconnectPeer(_that.peerId);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String dataDir)?  init,TResult? Function()?  startEngine,TResult? Function()?  stopEngine,TResult? Function( String message)?  saveMessage,TResult? Function( String peerId)?  getMessages,TResult? Function( String peerId,  String filePath)?  sendFile,TResult? Function( String offerId,  String peerId,  BigInt fileSize,  String destPath)?  acceptFile,TResult? Function( String transferId)?  cancelTransfer,TResult? Function( String peerId)?  markMessagesRead,TResult? Function( String offerId,  String peerId)?  rejectFile,TResult? Function()?  generateCredentials,TResult? Function()?  generateQrPayload,TResult? Function( String pin)?  joinSession,TResult? Function( String key,  String text)?  setSettings,TResult? Function( String key)?  getSettings,TResult? Function()?  generateSessionCode,TResult? Function( String text)?  joinSessionCode,TResult? Function( String name)?  setDeviceName,TResult? Function()?  startDiscovery,TResult? Function()?  generateCode,TResult? Function( String peerId,  String address,  int port,  String? encryptionKey)?  connectPeer,TResult? Function( String peerId,  String text)?  sendMessage,TResult? Function()?  stopDiscovery,TResult? Function( String peerId)?  disconnectPeer,}) {final _that = this;
switch (_that) {
case DaemonCommand_Init() when init != null:
return init(_that.dataDir);case DaemonCommand_StartEngine() when startEngine != null:
return startEngine();case DaemonCommand_StopEngine() when stopEngine != null:
return stopEngine();case DaemonCommand_SaveMessage() when saveMessage != null:
return saveMessage(_that.message);case DaemonCommand_GetMessages() when getMessages != null:
return getMessages(_that.peerId);case DaemonCommand_SendFile() when sendFile != null:
return sendFile(_that.peerId,_that.filePath);case DaemonCommand_AcceptFile() when acceptFile != null:
return acceptFile(_that.offerId,_that.peerId,_that.fileSize,_that.destPath);case DaemonCommand_CancelTransfer() when cancelTransfer != null:
return cancelTransfer(_that.transferId);case DaemonCommand_MarkMessagesRead() when markMessagesRead != null:
return markMessagesRead(_that.peerId);case DaemonCommand_RejectFile() when rejectFile != null:
return rejectFile(_that.offerId,_that.peerId);case DaemonCommand_GenerateCredentials() when generateCredentials != null:
return generateCredentials();case DaemonCommand_GenerateQrPayload() when generateQrPayload != null:
return generateQrPayload();case DaemonCommand_JoinSession() when joinSession != null:
return joinSession(_that.pin);case DaemonCommand_SetSettings() when setSettings != null:
return setSettings(_that.key,_that.text);case DaemonCommand_GetSettings() when getSettings != null:
return getSettings(_that.key);case DaemonCommand_GenerateSessionCode() when generateSessionCode != null:
return generateSessionCode();case DaemonCommand_JoinSessionCode() when joinSessionCode != null:
return joinSessionCode(_that.text);case DaemonCommand_SetDeviceName() when setDeviceName != null:
return setDeviceName(_that.name);case DaemonCommand_StartDiscovery() when startDiscovery != null:
return startDiscovery();case DaemonCommand_GenerateCode() when generateCode != null:
return generateCode();case DaemonCommand_ConnectPeer() when connectPeer != null:
return connectPeer(_that.peerId,_that.address,_that.port,_that.encryptionKey);case DaemonCommand_SendMessage() when sendMessage != null:
return sendMessage(_that.peerId,_that.text);case DaemonCommand_StopDiscovery() when stopDiscovery != null:
return stopDiscovery();case DaemonCommand_DisconnectPeer() when disconnectPeer != null:
return disconnectPeer(_that.peerId);case _:
  return null;

}
}

}

/// @nodoc


class DaemonCommand_Init extends DaemonCommand {
  const DaemonCommand_Init({required this.dataDir}): super._();
  

 final  String dataDir;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_InitCopyWith<DaemonCommand_Init> get copyWith => _$DaemonCommand_InitCopyWithImpl<DaemonCommand_Init>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_Init&&(identical(other.dataDir, dataDir) || other.dataDir == dataDir));
}


@override
int get hashCode => Object.hash(runtimeType,dataDir);

@override
String toString() {
  return 'DaemonCommand.init(dataDir: $dataDir)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_InitCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_InitCopyWith(DaemonCommand_Init value, $Res Function(DaemonCommand_Init) _then) = _$DaemonCommand_InitCopyWithImpl;
@useResult
$Res call({
 String dataDir
});




}
/// @nodoc
class _$DaemonCommand_InitCopyWithImpl<$Res>
    implements $DaemonCommand_InitCopyWith<$Res> {
  _$DaemonCommand_InitCopyWithImpl(this._self, this._then);

  final DaemonCommand_Init _self;
  final $Res Function(DaemonCommand_Init) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? dataDir = null,}) {
  return _then(DaemonCommand_Init(
dataDir: null == dataDir ? _self.dataDir : dataDir // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_StartEngine extends DaemonCommand {
  const DaemonCommand_StartEngine(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_StartEngine);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DaemonCommand.startEngine()';
}


}




/// @nodoc


class DaemonCommand_StopEngine extends DaemonCommand {
  const DaemonCommand_StopEngine(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_StopEngine);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DaemonCommand.stopEngine()';
}


}




/// @nodoc


class DaemonCommand_SaveMessage extends DaemonCommand {
  const DaemonCommand_SaveMessage({required this.message}): super._();
  

 final  String message;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_SaveMessageCopyWith<DaemonCommand_SaveMessage> get copyWith => _$DaemonCommand_SaveMessageCopyWithImpl<DaemonCommand_SaveMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_SaveMessage&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'DaemonCommand.saveMessage(message: $message)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_SaveMessageCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_SaveMessageCopyWith(DaemonCommand_SaveMessage value, $Res Function(DaemonCommand_SaveMessage) _then) = _$DaemonCommand_SaveMessageCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$DaemonCommand_SaveMessageCopyWithImpl<$Res>
    implements $DaemonCommand_SaveMessageCopyWith<$Res> {
  _$DaemonCommand_SaveMessageCopyWithImpl(this._self, this._then);

  final DaemonCommand_SaveMessage _self;
  final $Res Function(DaemonCommand_SaveMessage) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(DaemonCommand_SaveMessage(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_GetMessages extends DaemonCommand {
  const DaemonCommand_GetMessages({required this.peerId}): super._();
  

 final  String peerId;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_GetMessagesCopyWith<DaemonCommand_GetMessages> get copyWith => _$DaemonCommand_GetMessagesCopyWithImpl<DaemonCommand_GetMessages>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_GetMessages&&(identical(other.peerId, peerId) || other.peerId == peerId));
}


@override
int get hashCode => Object.hash(runtimeType,peerId);

@override
String toString() {
  return 'DaemonCommand.getMessages(peerId: $peerId)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_GetMessagesCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_GetMessagesCopyWith(DaemonCommand_GetMessages value, $Res Function(DaemonCommand_GetMessages) _then) = _$DaemonCommand_GetMessagesCopyWithImpl;
@useResult
$Res call({
 String peerId
});




}
/// @nodoc
class _$DaemonCommand_GetMessagesCopyWithImpl<$Res>
    implements $DaemonCommand_GetMessagesCopyWith<$Res> {
  _$DaemonCommand_GetMessagesCopyWithImpl(this._self, this._then);

  final DaemonCommand_GetMessages _self;
  final $Res Function(DaemonCommand_GetMessages) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,}) {
  return _then(DaemonCommand_GetMessages(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_SendFile extends DaemonCommand {
  const DaemonCommand_SendFile({required this.peerId, required this.filePath}): super._();
  

 final  String peerId;
 final  String filePath;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_SendFileCopyWith<DaemonCommand_SendFile> get copyWith => _$DaemonCommand_SendFileCopyWithImpl<DaemonCommand_SendFile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_SendFile&&(identical(other.peerId, peerId) || other.peerId == peerId)&&(identical(other.filePath, filePath) || other.filePath == filePath));
}


@override
int get hashCode => Object.hash(runtimeType,peerId,filePath);

@override
String toString() {
  return 'DaemonCommand.sendFile(peerId: $peerId, filePath: $filePath)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_SendFileCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_SendFileCopyWith(DaemonCommand_SendFile value, $Res Function(DaemonCommand_SendFile) _then) = _$DaemonCommand_SendFileCopyWithImpl;
@useResult
$Res call({
 String peerId, String filePath
});




}
/// @nodoc
class _$DaemonCommand_SendFileCopyWithImpl<$Res>
    implements $DaemonCommand_SendFileCopyWith<$Res> {
  _$DaemonCommand_SendFileCopyWithImpl(this._self, this._then);

  final DaemonCommand_SendFile _self;
  final $Res Function(DaemonCommand_SendFile) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,Object? filePath = null,}) {
  return _then(DaemonCommand_SendFile(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_AcceptFile extends DaemonCommand {
  const DaemonCommand_AcceptFile({required this.offerId, required this.peerId, required this.fileSize, required this.destPath}): super._();
  

 final  String offerId;
 final  String peerId;
 final  BigInt fileSize;
 final  String destPath;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_AcceptFileCopyWith<DaemonCommand_AcceptFile> get copyWith => _$DaemonCommand_AcceptFileCopyWithImpl<DaemonCommand_AcceptFile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_AcceptFile&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.peerId, peerId) || other.peerId == peerId)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.destPath, destPath) || other.destPath == destPath));
}


@override
int get hashCode => Object.hash(runtimeType,offerId,peerId,fileSize,destPath);

@override
String toString() {
  return 'DaemonCommand.acceptFile(offerId: $offerId, peerId: $peerId, fileSize: $fileSize, destPath: $destPath)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_AcceptFileCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_AcceptFileCopyWith(DaemonCommand_AcceptFile value, $Res Function(DaemonCommand_AcceptFile) _then) = _$DaemonCommand_AcceptFileCopyWithImpl;
@useResult
$Res call({
 String offerId, String peerId, BigInt fileSize, String destPath
});




}
/// @nodoc
class _$DaemonCommand_AcceptFileCopyWithImpl<$Res>
    implements $DaemonCommand_AcceptFileCopyWith<$Res> {
  _$DaemonCommand_AcceptFileCopyWithImpl(this._self, this._then);

  final DaemonCommand_AcceptFile _self;
  final $Res Function(DaemonCommand_AcceptFile) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? offerId = null,Object? peerId = null,Object? fileSize = null,Object? destPath = null,}) {
  return _then(DaemonCommand_AcceptFile(
offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as BigInt,destPath: null == destPath ? _self.destPath : destPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_CancelTransfer extends DaemonCommand {
  const DaemonCommand_CancelTransfer({required this.transferId}): super._();
  

 final  String transferId;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_CancelTransferCopyWith<DaemonCommand_CancelTransfer> get copyWith => _$DaemonCommand_CancelTransferCopyWithImpl<DaemonCommand_CancelTransfer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_CancelTransfer&&(identical(other.transferId, transferId) || other.transferId == transferId));
}


@override
int get hashCode => Object.hash(runtimeType,transferId);

@override
String toString() {
  return 'DaemonCommand.cancelTransfer(transferId: $transferId)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_CancelTransferCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_CancelTransferCopyWith(DaemonCommand_CancelTransfer value, $Res Function(DaemonCommand_CancelTransfer) _then) = _$DaemonCommand_CancelTransferCopyWithImpl;
@useResult
$Res call({
 String transferId
});




}
/// @nodoc
class _$DaemonCommand_CancelTransferCopyWithImpl<$Res>
    implements $DaemonCommand_CancelTransferCopyWith<$Res> {
  _$DaemonCommand_CancelTransferCopyWithImpl(this._self, this._then);

  final DaemonCommand_CancelTransfer _self;
  final $Res Function(DaemonCommand_CancelTransfer) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? transferId = null,}) {
  return _then(DaemonCommand_CancelTransfer(
transferId: null == transferId ? _self.transferId : transferId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_MarkMessagesRead extends DaemonCommand {
  const DaemonCommand_MarkMessagesRead({required this.peerId}): super._();
  

 final  String peerId;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_MarkMessagesReadCopyWith<DaemonCommand_MarkMessagesRead> get copyWith => _$DaemonCommand_MarkMessagesReadCopyWithImpl<DaemonCommand_MarkMessagesRead>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_MarkMessagesRead&&(identical(other.peerId, peerId) || other.peerId == peerId));
}


@override
int get hashCode => Object.hash(runtimeType,peerId);

@override
String toString() {
  return 'DaemonCommand.markMessagesRead(peerId: $peerId)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_MarkMessagesReadCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_MarkMessagesReadCopyWith(DaemonCommand_MarkMessagesRead value, $Res Function(DaemonCommand_MarkMessagesRead) _then) = _$DaemonCommand_MarkMessagesReadCopyWithImpl;
@useResult
$Res call({
 String peerId
});




}
/// @nodoc
class _$DaemonCommand_MarkMessagesReadCopyWithImpl<$Res>
    implements $DaemonCommand_MarkMessagesReadCopyWith<$Res> {
  _$DaemonCommand_MarkMessagesReadCopyWithImpl(this._self, this._then);

  final DaemonCommand_MarkMessagesRead _self;
  final $Res Function(DaemonCommand_MarkMessagesRead) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,}) {
  return _then(DaemonCommand_MarkMessagesRead(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_RejectFile extends DaemonCommand {
  const DaemonCommand_RejectFile({required this.offerId, required this.peerId}): super._();
  

 final  String offerId;
 final  String peerId;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_RejectFileCopyWith<DaemonCommand_RejectFile> get copyWith => _$DaemonCommand_RejectFileCopyWithImpl<DaemonCommand_RejectFile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_RejectFile&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.peerId, peerId) || other.peerId == peerId));
}


@override
int get hashCode => Object.hash(runtimeType,offerId,peerId);

@override
String toString() {
  return 'DaemonCommand.rejectFile(offerId: $offerId, peerId: $peerId)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_RejectFileCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_RejectFileCopyWith(DaemonCommand_RejectFile value, $Res Function(DaemonCommand_RejectFile) _then) = _$DaemonCommand_RejectFileCopyWithImpl;
@useResult
$Res call({
 String offerId, String peerId
});




}
/// @nodoc
class _$DaemonCommand_RejectFileCopyWithImpl<$Res>
    implements $DaemonCommand_RejectFileCopyWith<$Res> {
  _$DaemonCommand_RejectFileCopyWithImpl(this._self, this._then);

  final DaemonCommand_RejectFile _self;
  final $Res Function(DaemonCommand_RejectFile) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? offerId = null,Object? peerId = null,}) {
  return _then(DaemonCommand_RejectFile(
offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_GenerateCredentials extends DaemonCommand {
  const DaemonCommand_GenerateCredentials(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_GenerateCredentials);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DaemonCommand.generateCredentials()';
}


}




/// @nodoc


class DaemonCommand_GenerateQrPayload extends DaemonCommand {
  const DaemonCommand_GenerateQrPayload(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_GenerateQrPayload);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DaemonCommand.generateQrPayload()';
}


}




/// @nodoc


class DaemonCommand_JoinSession extends DaemonCommand {
  const DaemonCommand_JoinSession({required this.pin}): super._();
  

 final  String pin;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_JoinSessionCopyWith<DaemonCommand_JoinSession> get copyWith => _$DaemonCommand_JoinSessionCopyWithImpl<DaemonCommand_JoinSession>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_JoinSession&&(identical(other.pin, pin) || other.pin == pin));
}


@override
int get hashCode => Object.hash(runtimeType,pin);

@override
String toString() {
  return 'DaemonCommand.joinSession(pin: $pin)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_JoinSessionCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_JoinSessionCopyWith(DaemonCommand_JoinSession value, $Res Function(DaemonCommand_JoinSession) _then) = _$DaemonCommand_JoinSessionCopyWithImpl;
@useResult
$Res call({
 String pin
});




}
/// @nodoc
class _$DaemonCommand_JoinSessionCopyWithImpl<$Res>
    implements $DaemonCommand_JoinSessionCopyWith<$Res> {
  _$DaemonCommand_JoinSessionCopyWithImpl(this._self, this._then);

  final DaemonCommand_JoinSession _self;
  final $Res Function(DaemonCommand_JoinSession) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pin = null,}) {
  return _then(DaemonCommand_JoinSession(
pin: null == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_SetSettings extends DaemonCommand {
  const DaemonCommand_SetSettings({required this.key, required this.text}): super._();
  

 final  String key;
 final  String text;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_SetSettingsCopyWith<DaemonCommand_SetSettings> get copyWith => _$DaemonCommand_SetSettingsCopyWithImpl<DaemonCommand_SetSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_SetSettings&&(identical(other.key, key) || other.key == key)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,key,text);

@override
String toString() {
  return 'DaemonCommand.setSettings(key: $key, text: $text)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_SetSettingsCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_SetSettingsCopyWith(DaemonCommand_SetSettings value, $Res Function(DaemonCommand_SetSettings) _then) = _$DaemonCommand_SetSettingsCopyWithImpl;
@useResult
$Res call({
 String key, String text
});




}
/// @nodoc
class _$DaemonCommand_SetSettingsCopyWithImpl<$Res>
    implements $DaemonCommand_SetSettingsCopyWith<$Res> {
  _$DaemonCommand_SetSettingsCopyWithImpl(this._self, this._then);

  final DaemonCommand_SetSettings _self;
  final $Res Function(DaemonCommand_SetSettings) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? key = null,Object? text = null,}) {
  return _then(DaemonCommand_SetSettings(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_GetSettings extends DaemonCommand {
  const DaemonCommand_GetSettings({required this.key}): super._();
  

 final  String key;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_GetSettingsCopyWith<DaemonCommand_GetSettings> get copyWith => _$DaemonCommand_GetSettingsCopyWithImpl<DaemonCommand_GetSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_GetSettings&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode => Object.hash(runtimeType,key);

@override
String toString() {
  return 'DaemonCommand.getSettings(key: $key)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_GetSettingsCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_GetSettingsCopyWith(DaemonCommand_GetSettings value, $Res Function(DaemonCommand_GetSettings) _then) = _$DaemonCommand_GetSettingsCopyWithImpl;
@useResult
$Res call({
 String key
});




}
/// @nodoc
class _$DaemonCommand_GetSettingsCopyWithImpl<$Res>
    implements $DaemonCommand_GetSettingsCopyWith<$Res> {
  _$DaemonCommand_GetSettingsCopyWithImpl(this._self, this._then);

  final DaemonCommand_GetSettings _self;
  final $Res Function(DaemonCommand_GetSettings) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? key = null,}) {
  return _then(DaemonCommand_GetSettings(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_GenerateSessionCode extends DaemonCommand {
  const DaemonCommand_GenerateSessionCode(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_GenerateSessionCode);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DaemonCommand.generateSessionCode()';
}


}




/// @nodoc


class DaemonCommand_JoinSessionCode extends DaemonCommand {
  const DaemonCommand_JoinSessionCode({required this.text}): super._();
  

 final  String text;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_JoinSessionCodeCopyWith<DaemonCommand_JoinSessionCode> get copyWith => _$DaemonCommand_JoinSessionCodeCopyWithImpl<DaemonCommand_JoinSessionCode>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_JoinSessionCode&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'DaemonCommand.joinSessionCode(text: $text)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_JoinSessionCodeCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_JoinSessionCodeCopyWith(DaemonCommand_JoinSessionCode value, $Res Function(DaemonCommand_JoinSessionCode) _then) = _$DaemonCommand_JoinSessionCodeCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$DaemonCommand_JoinSessionCodeCopyWithImpl<$Res>
    implements $DaemonCommand_JoinSessionCodeCopyWith<$Res> {
  _$DaemonCommand_JoinSessionCodeCopyWithImpl(this._self, this._then);

  final DaemonCommand_JoinSessionCode _self;
  final $Res Function(DaemonCommand_JoinSessionCode) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(DaemonCommand_JoinSessionCode(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_SetDeviceName extends DaemonCommand {
  const DaemonCommand_SetDeviceName({required this.name}): super._();
  

 final  String name;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_SetDeviceNameCopyWith<DaemonCommand_SetDeviceName> get copyWith => _$DaemonCommand_SetDeviceNameCopyWithImpl<DaemonCommand_SetDeviceName>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_SetDeviceName&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'DaemonCommand.setDeviceName(name: $name)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_SetDeviceNameCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_SetDeviceNameCopyWith(DaemonCommand_SetDeviceName value, $Res Function(DaemonCommand_SetDeviceName) _then) = _$DaemonCommand_SetDeviceNameCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$DaemonCommand_SetDeviceNameCopyWithImpl<$Res>
    implements $DaemonCommand_SetDeviceNameCopyWith<$Res> {
  _$DaemonCommand_SetDeviceNameCopyWithImpl(this._self, this._then);

  final DaemonCommand_SetDeviceName _self;
  final $Res Function(DaemonCommand_SetDeviceName) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(DaemonCommand_SetDeviceName(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_StartDiscovery extends DaemonCommand {
  const DaemonCommand_StartDiscovery(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_StartDiscovery);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DaemonCommand.startDiscovery()';
}


}




/// @nodoc


class DaemonCommand_GenerateCode extends DaemonCommand {
  const DaemonCommand_GenerateCode(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_GenerateCode);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DaemonCommand.generateCode()';
}


}




/// @nodoc


class DaemonCommand_ConnectPeer extends DaemonCommand {
  const DaemonCommand_ConnectPeer({required this.peerId, required this.address, required this.port, this.encryptionKey}): super._();
  

 final  String peerId;
 final  String address;
 final  int port;
 final  String? encryptionKey;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_ConnectPeerCopyWith<DaemonCommand_ConnectPeer> get copyWith => _$DaemonCommand_ConnectPeerCopyWithImpl<DaemonCommand_ConnectPeer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_ConnectPeer&&(identical(other.peerId, peerId) || other.peerId == peerId)&&(identical(other.address, address) || other.address == address)&&(identical(other.port, port) || other.port == port)&&(identical(other.encryptionKey, encryptionKey) || other.encryptionKey == encryptionKey));
}


@override
int get hashCode => Object.hash(runtimeType,peerId,address,port,encryptionKey);

@override
String toString() {
  return 'DaemonCommand.connectPeer(peerId: $peerId, address: $address, port: $port, encryptionKey: $encryptionKey)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_ConnectPeerCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_ConnectPeerCopyWith(DaemonCommand_ConnectPeer value, $Res Function(DaemonCommand_ConnectPeer) _then) = _$DaemonCommand_ConnectPeerCopyWithImpl;
@useResult
$Res call({
 String peerId, String address, int port, String? encryptionKey
});




}
/// @nodoc
class _$DaemonCommand_ConnectPeerCopyWithImpl<$Res>
    implements $DaemonCommand_ConnectPeerCopyWith<$Res> {
  _$DaemonCommand_ConnectPeerCopyWithImpl(this._self, this._then);

  final DaemonCommand_ConnectPeer _self;
  final $Res Function(DaemonCommand_ConnectPeer) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,Object? address = null,Object? port = null,Object? encryptionKey = freezed,}) {
  return _then(DaemonCommand_ConnectPeer(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,encryptionKey: freezed == encryptionKey ? _self.encryptionKey : encryptionKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class DaemonCommand_SendMessage extends DaemonCommand {
  const DaemonCommand_SendMessage({required this.peerId, required this.text}): super._();


 final  String peerId;
 final  String text;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_SendMessageCopyWith<DaemonCommand_SendMessage> get copyWith => _$DaemonCommand_SendMessageCopyWithImpl<DaemonCommand_SendMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_SendMessage&&(identical(other.peerId, peerId) || other.peerId == peerId)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,peerId,text);

@override
String toString() {
  return 'DaemonCommand.sendMessage(peerId: $peerId, text: $text)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_SendMessageCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_SendMessageCopyWith(DaemonCommand_SendMessage value, $Res Function(DaemonCommand_SendMessage) _then) = _$DaemonCommand_SendMessageCopyWithImpl;
@useResult
$Res call({
 String peerId, String text
});




}
/// @nodoc
class _$DaemonCommand_SendMessageCopyWithImpl<$Res>
    implements $DaemonCommand_SendMessageCopyWith<$Res> {
  _$DaemonCommand_SendMessageCopyWithImpl(this._self, this._then);

  final DaemonCommand_SendMessage _self;
  final $Res Function(DaemonCommand_SendMessage) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,Object? text = null,}) {
  return _then(DaemonCommand_SendMessage(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonCommand_StopDiscovery extends DaemonCommand {
  const DaemonCommand_StopDiscovery(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_StopDiscovery);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DaemonCommand.stopDiscovery()';
}


}




/// @nodoc


class DaemonCommand_DisconnectPeer extends DaemonCommand {
  const DaemonCommand_DisconnectPeer({required this.peerId}): super._();
  

 final  String peerId;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonCommand_DisconnectPeerCopyWith<DaemonCommand_DisconnectPeer> get copyWith => _$DaemonCommand_DisconnectPeerCopyWithImpl<DaemonCommand_DisconnectPeer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonCommand_DisconnectPeer&&(identical(other.peerId, peerId) || other.peerId == peerId));
}


@override
int get hashCode => Object.hash(runtimeType,peerId);

@override
String toString() {
  return 'DaemonCommand.disconnectPeer(peerId: $peerId)';
}


}

/// @nodoc
abstract mixin class $DaemonCommand_DisconnectPeerCopyWith<$Res> implements $DaemonCommandCopyWith<$Res> {
  factory $DaemonCommand_DisconnectPeerCopyWith(DaemonCommand_DisconnectPeer value, $Res Function(DaemonCommand_DisconnectPeer) _then) = _$DaemonCommand_DisconnectPeerCopyWithImpl;
@useResult
$Res call({
 String peerId
});




}
/// @nodoc
class _$DaemonCommand_DisconnectPeerCopyWithImpl<$Res>
    implements $DaemonCommand_DisconnectPeerCopyWith<$Res> {
  _$DaemonCommand_DisconnectPeerCopyWithImpl(this._self, this._then);

  final DaemonCommand_DisconnectPeer _self;
  final $Res Function(DaemonCommand_DisconnectPeer) _then;

/// Create a copy of DaemonCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,}) {
  return _then(DaemonCommand_DisconnectPeer(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$DaemonEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DaemonEvent()';
}


}

/// @nodoc
class $DaemonEventCopyWith<$Res>  {
$DaemonEventCopyWith(DaemonEvent _, $Res Function(DaemonEvent) __);
}


/// Adds pattern-matching-related methods to [DaemonEvent].
extension DaemonEventPatterns on DaemonEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DaemonEvent_PeerDiscovered value)?  peerDiscovered,TResult Function( DaemonEvent_PeerLost value)?  peerLost,TResult Function( DaemonEvent_TransferProgress value)?  transferProgress,TResult Function( DaemonEvent_TransferComplete value)?  transferComplete,TResult Function( DaemonEvent_PairingRequest value)?  pairingRequest,TResult Function( DaemonEvent_TransferOffer value)?  transferOffer,TResult Function( DaemonEvent_LogMessage value)?  logMessage,TResult Function( DaemonEvent_CredentialsGenerated value)?  credentialsGenerated,TResult Function( DaemonEvent_QrPayloadGenerated value)?  qrPayloadGenerated,TResult Function( DaemonEvent_SettingReported value)?  settingReported,TResult Function( DaemonEvent_SessionCodeGenerated value)?  sessionCodeGenerated,TResult Function( DaemonEvent_SignalingStarted value)?  signalingStarted,TResult Function( DaemonEvent_CodeGenerated value)?  codeGenerated,TResult Function( DaemonEvent_PeerDisconnected value)?  peerDisconnected,TResult Function( DaemonEvent_PeerConnected value)?  peerConnected,TResult Function( DaemonEvent_IncomingChat value)?  incomingChat,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DaemonEvent_PeerDiscovered() when peerDiscovered != null:
return peerDiscovered(_that);case DaemonEvent_PeerLost() when peerLost != null:
return peerLost(_that);case DaemonEvent_TransferProgress() when transferProgress != null:
return transferProgress(_that);case DaemonEvent_TransferComplete() when transferComplete != null:
return transferComplete(_that);case DaemonEvent_PairingRequest() when pairingRequest != null:
return pairingRequest(_that);case DaemonEvent_TransferOffer() when transferOffer != null:
return transferOffer(_that);case DaemonEvent_LogMessage() when logMessage != null:
return logMessage(_that);case DaemonEvent_CredentialsGenerated() when credentialsGenerated != null:
return credentialsGenerated(_that);case DaemonEvent_QrPayloadGenerated() when qrPayloadGenerated != null:
return qrPayloadGenerated(_that);case DaemonEvent_SettingReported() when settingReported != null:
return settingReported(_that);case DaemonEvent_SessionCodeGenerated() when sessionCodeGenerated != null:
return sessionCodeGenerated(_that);case DaemonEvent_SignalingStarted() when signalingStarted != null:
return signalingStarted(_that);case DaemonEvent_CodeGenerated() when codeGenerated != null:
return codeGenerated(_that);case DaemonEvent_PeerDisconnected() when peerDisconnected != null:
return peerDisconnected(_that);case DaemonEvent_PeerConnected() when peerConnected != null:
return peerConnected(_that);case DaemonEvent_IncomingChat() when incomingChat != null:
return incomingChat(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DaemonEvent_PeerDiscovered value)  peerDiscovered,required TResult Function( DaemonEvent_PeerLost value)  peerLost,required TResult Function( DaemonEvent_TransferProgress value)  transferProgress,required TResult Function( DaemonEvent_TransferComplete value)  transferComplete,required TResult Function( DaemonEvent_PairingRequest value)  pairingRequest,required TResult Function( DaemonEvent_TransferOffer value)  transferOffer,required TResult Function( DaemonEvent_LogMessage value)  logMessage,required TResult Function( DaemonEvent_CredentialsGenerated value)  credentialsGenerated,required TResult Function( DaemonEvent_QrPayloadGenerated value)  qrPayloadGenerated,required TResult Function( DaemonEvent_SettingReported value)  settingReported,required TResult Function( DaemonEvent_SessionCodeGenerated value)  sessionCodeGenerated,required TResult Function( DaemonEvent_SignalingStarted value)  signalingStarted,required TResult Function( DaemonEvent_CodeGenerated value)  codeGenerated,required TResult Function( DaemonEvent_PeerDisconnected value)  peerDisconnected,required TResult Function( DaemonEvent_PeerConnected value)  peerConnected,required TResult Function( DaemonEvent_IncomingChat value)  incomingChat,}){
final _that = this;
switch (_that) {
case DaemonEvent_PeerDiscovered():
return peerDiscovered(_that);case DaemonEvent_PeerLost():
return peerLost(_that);case DaemonEvent_TransferProgress():
return transferProgress(_that);case DaemonEvent_TransferComplete():
return transferComplete(_that);case DaemonEvent_PairingRequest():
return pairingRequest(_that);case DaemonEvent_TransferOffer():
return transferOffer(_that);case DaemonEvent_LogMessage():
return logMessage(_that);case DaemonEvent_CredentialsGenerated():
return credentialsGenerated(_that);case DaemonEvent_QrPayloadGenerated():
return qrPayloadGenerated(_that);case DaemonEvent_SettingReported():
return settingReported(_that);case DaemonEvent_SessionCodeGenerated():
return sessionCodeGenerated(_that);case DaemonEvent_SignalingStarted():
return signalingStarted(_that);case DaemonEvent_CodeGenerated():
return codeGenerated(_that);case DaemonEvent_PeerDisconnected():
return peerDisconnected(_that);case DaemonEvent_PeerConnected():
return peerConnected(_that);case DaemonEvent_IncomingChat():
return incomingChat(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DaemonEvent_PeerDiscovered value)?  peerDiscovered,TResult? Function( DaemonEvent_PeerLost value)?  peerLost,TResult? Function( DaemonEvent_TransferProgress value)?  transferProgress,TResult? Function( DaemonEvent_TransferComplete value)?  transferComplete,TResult? Function( DaemonEvent_PairingRequest value)?  pairingRequest,TResult? Function( DaemonEvent_TransferOffer value)?  transferOffer,TResult? Function( DaemonEvent_LogMessage value)?  logMessage,TResult? Function( DaemonEvent_CredentialsGenerated value)?  credentialsGenerated,TResult? Function( DaemonEvent_QrPayloadGenerated value)?  qrPayloadGenerated,TResult? Function( DaemonEvent_SettingReported value)?  settingReported,TResult? Function( DaemonEvent_SessionCodeGenerated value)?  sessionCodeGenerated,TResult? Function( DaemonEvent_SignalingStarted value)?  signalingStarted,TResult? Function( DaemonEvent_CodeGenerated value)?  codeGenerated,TResult? Function( DaemonEvent_PeerDisconnected value)?  peerDisconnected,TResult? Function( DaemonEvent_PeerConnected value)?  peerConnected,TResult? Function( DaemonEvent_IncomingChat value)?  incomingChat,}){
final _that = this;
switch (_that) {
case DaemonEvent_PeerDiscovered() when peerDiscovered != null:
return peerDiscovered(_that);case DaemonEvent_PeerLost() when peerLost != null:
return peerLost(_that);case DaemonEvent_TransferProgress() when transferProgress != null:
return transferProgress(_that);case DaemonEvent_TransferComplete() when transferComplete != null:
return transferComplete(_that);case DaemonEvent_PairingRequest() when pairingRequest != null:
return pairingRequest(_that);case DaemonEvent_TransferOffer() when transferOffer != null:
return transferOffer(_that);case DaemonEvent_LogMessage() when logMessage != null:
return logMessage(_that);case DaemonEvent_CredentialsGenerated() when credentialsGenerated != null:
return credentialsGenerated(_that);case DaemonEvent_QrPayloadGenerated() when qrPayloadGenerated != null:
return qrPayloadGenerated(_that);case DaemonEvent_SettingReported() when settingReported != null:
return settingReported(_that);case DaemonEvent_SessionCodeGenerated() when sessionCodeGenerated != null:
return sessionCodeGenerated(_that);case DaemonEvent_SignalingStarted() when signalingStarted != null:
return signalingStarted(_that);case DaemonEvent_CodeGenerated() when codeGenerated != null:
return codeGenerated(_that);case DaemonEvent_PeerDisconnected() when peerDisconnected != null:
return peerDisconnected(_that);case DaemonEvent_PeerConnected() when peerConnected != null:
return peerConnected(_that);case DaemonEvent_IncomingChat() when incomingChat != null:
return incomingChat(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String peerId,  String name,  String ip,  int port)?  peerDiscovered,TResult Function( String peerId)?  peerLost,TResult Function( String transferId,  BigInt bytesTransferred,  BigInt totalBytes,  double speed)?  transferProgress,TResult Function( String transferId,  String status)?  transferComplete,TResult Function( String peerId,  String pin)?  pairingRequest,TResult Function( String peerId,  String transferId,  String fileName,  BigInt fileSize,  String? thumbnail)?  transferOffer,TResult Function( String level,  String message)?  logMessage,TResult Function( String pin,  String sessionKey)?  credentialsGenerated,TResult Function( String payloadJson)?  qrPayloadGenerated,TResult Function( String key,  String value)?  settingReported,TResult Function( String code)?  sessionCodeGenerated,TResult Function( String id)?  signalingStarted,TResult Function( String key,  String? pin,  String ip)?  codeGenerated,TResult Function( String peerId)?  peerDisconnected,TResult Function( String peerId,  String name,  String address,  int port)?  peerConnected,TResult Function( String peerId,  String text)?  incomingChat,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DaemonEvent_PeerDiscovered() when peerDiscovered != null:
return peerDiscovered(_that.peerId,_that.name,_that.ip,_that.port);case DaemonEvent_PeerLost() when peerLost != null:
return peerLost(_that.peerId);case DaemonEvent_TransferProgress() when transferProgress != null:
return transferProgress(_that.transferId,_that.bytesTransferred,_that.totalBytes,_that.speed);case DaemonEvent_TransferComplete() when transferComplete != null:
return transferComplete(_that.transferId,_that.status);case DaemonEvent_PairingRequest() when pairingRequest != null:
return pairingRequest(_that.peerId,_that.pin);case DaemonEvent_TransferOffer() when transferOffer != null:
return transferOffer(_that.peerId,_that.transferId,_that.fileName,_that.fileSize,_that.thumbnail);case DaemonEvent_LogMessage() when logMessage != null:
return logMessage(_that.level,_that.message);case DaemonEvent_CredentialsGenerated() when credentialsGenerated != null:
return credentialsGenerated(_that.pin,_that.sessionKey);case DaemonEvent_QrPayloadGenerated() when qrPayloadGenerated != null:
return qrPayloadGenerated(_that.payloadJson);case DaemonEvent_SettingReported() when settingReported != null:
return settingReported(_that.key,_that.value);case DaemonEvent_SessionCodeGenerated() when sessionCodeGenerated != null:
return sessionCodeGenerated(_that.code);case DaemonEvent_SignalingStarted() when signalingStarted != null:
return signalingStarted(_that.id);case DaemonEvent_CodeGenerated() when codeGenerated != null:
return codeGenerated(_that.key,_that.pin,_that.ip);case DaemonEvent_PeerDisconnected() when peerDisconnected != null:
return peerDisconnected(_that.peerId);case DaemonEvent_PeerConnected() when peerConnected != null:
return peerConnected(_that.peerId,_that.name,_that.address,_that.port);case DaemonEvent_IncomingChat() when incomingChat != null:
return incomingChat(_that.peerId,_that.text);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String peerId,  String name,  String ip,  int port)  peerDiscovered,required TResult Function( String peerId)  peerLost,required TResult Function( String transferId,  BigInt bytesTransferred,  BigInt totalBytes,  double speed)  transferProgress,required TResult Function( String transferId,  String status)  transferComplete,required TResult Function( String peerId,  String pin)  pairingRequest,required TResult Function( String peerId,  String transferId,  String fileName,  BigInt fileSize,  String? thumbnail)  transferOffer,required TResult Function( String level,  String message)  logMessage,required TResult Function( String pin,  String sessionKey)  credentialsGenerated,required TResult Function( String payloadJson)  qrPayloadGenerated,required TResult Function( String key,  String value)  settingReported,required TResult Function( String code)  sessionCodeGenerated,required TResult Function( String id)  signalingStarted,required TResult Function( String key,  String? pin,  String ip)  codeGenerated,required TResult Function( String peerId)  peerDisconnected,required TResult Function( String peerId,  String name,  String address,  int port)  peerConnected,required TResult Function( String peerId,  String text)  incomingChat,}) {final _that = this;
switch (_that) {
case DaemonEvent_PeerDiscovered():
return peerDiscovered(_that.peerId,_that.name,_that.ip,_that.port);case DaemonEvent_PeerLost():
return peerLost(_that.peerId);case DaemonEvent_TransferProgress():
return transferProgress(_that.transferId,_that.bytesTransferred,_that.totalBytes,_that.speed);case DaemonEvent_TransferComplete():
return transferComplete(_that.transferId,_that.status);case DaemonEvent_PairingRequest():
return pairingRequest(_that.peerId,_that.pin);case DaemonEvent_TransferOffer():
return transferOffer(_that.peerId,_that.transferId,_that.fileName,_that.fileSize,_that.thumbnail);case DaemonEvent_LogMessage():
return logMessage(_that.level,_that.message);case DaemonEvent_CredentialsGenerated():
return credentialsGenerated(_that.pin,_that.sessionKey);case DaemonEvent_QrPayloadGenerated():
return qrPayloadGenerated(_that.payloadJson);case DaemonEvent_SettingReported():
return settingReported(_that.key,_that.value);case DaemonEvent_SessionCodeGenerated():
return sessionCodeGenerated(_that.code);case DaemonEvent_SignalingStarted():
return signalingStarted(_that.id);case DaemonEvent_CodeGenerated():
return codeGenerated(_that.key,_that.pin,_that.ip);case DaemonEvent_PeerDisconnected():
return peerDisconnected(_that.peerId);case DaemonEvent_PeerConnected():
return peerConnected(_that.peerId,_that.name,_that.address,_that.port);case DaemonEvent_IncomingChat():
return incomingChat(_that.peerId,_that.text);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String peerId,  String name,  String ip,  int port)?  peerDiscovered,TResult? Function( String peerId)?  peerLost,TResult? Function( String transferId,  BigInt bytesTransferred,  BigInt totalBytes,  double speed)?  transferProgress,TResult? Function( String transferId,  String status)?  transferComplete,TResult? Function( String peerId,  String pin)?  pairingRequest,TResult? Function( String peerId,  String transferId,  String fileName,  BigInt fileSize,  String? thumbnail)?  transferOffer,TResult? Function( String level,  String message)?  logMessage,TResult? Function( String pin,  String sessionKey)?  credentialsGenerated,TResult? Function( String payloadJson)?  qrPayloadGenerated,TResult? Function( String key,  String value)?  settingReported,TResult? Function( String code)?  sessionCodeGenerated,TResult? Function( String id)?  signalingStarted,TResult? Function( String key,  String? pin,  String ip)?  codeGenerated,TResult? Function( String peerId)?  peerDisconnected,TResult? Function( String peerId,  String name,  String address,  int port)?  peerConnected,TResult? Function( String peerId,  String text)?  incomingChat,}) {final _that = this;
switch (_that) {
case DaemonEvent_PeerDiscovered() when peerDiscovered != null:
return peerDiscovered(_that.peerId,_that.name,_that.ip,_that.port);case DaemonEvent_PeerLost() when peerLost != null:
return peerLost(_that.peerId);case DaemonEvent_TransferProgress() when transferProgress != null:
return transferProgress(_that.transferId,_that.bytesTransferred,_that.totalBytes,_that.speed);case DaemonEvent_TransferComplete() when transferComplete != null:
return transferComplete(_that.transferId,_that.status);case DaemonEvent_PairingRequest() when pairingRequest != null:
return pairingRequest(_that.peerId,_that.pin);case DaemonEvent_TransferOffer() when transferOffer != null:
return transferOffer(_that.peerId,_that.transferId,_that.fileName,_that.fileSize,_that.thumbnail);case DaemonEvent_LogMessage() when logMessage != null:
return logMessage(_that.level,_that.message);case DaemonEvent_CredentialsGenerated() when credentialsGenerated != null:
return credentialsGenerated(_that.pin,_that.sessionKey);case DaemonEvent_QrPayloadGenerated() when qrPayloadGenerated != null:
return qrPayloadGenerated(_that.payloadJson);case DaemonEvent_SettingReported() when settingReported != null:
return settingReported(_that.key,_that.value);case DaemonEvent_SessionCodeGenerated() when sessionCodeGenerated != null:
return sessionCodeGenerated(_that.code);case DaemonEvent_SignalingStarted() when signalingStarted != null:
return signalingStarted(_that.id);case DaemonEvent_CodeGenerated() when codeGenerated != null:
return codeGenerated(_that.key,_that.pin,_that.ip);case DaemonEvent_PeerDisconnected() when peerDisconnected != null:
return peerDisconnected(_that.peerId);case DaemonEvent_PeerConnected() when peerConnected != null:
return peerConnected(_that.peerId,_that.name,_that.address,_that.port);case DaemonEvent_IncomingChat() when incomingChat != null:
return incomingChat(_that.peerId,_that.text);case _:
  return null;

}
}

}

/// @nodoc


class DaemonEvent_PeerDiscovered extends DaemonEvent {
  const DaemonEvent_PeerDiscovered({required this.peerId, required this.name, required this.ip, required this.port}): super._();
  

 final  String peerId;
 final  String name;
 final  String ip;
 final  int port;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_PeerDiscoveredCopyWith<DaemonEvent_PeerDiscovered> get copyWith => _$DaemonEvent_PeerDiscoveredCopyWithImpl<DaemonEvent_PeerDiscovered>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_PeerDiscovered&&(identical(other.peerId, peerId) || other.peerId == peerId)&&(identical(other.name, name) || other.name == name)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.port, port) || other.port == port));
}


@override
int get hashCode => Object.hash(runtimeType,peerId,name,ip,port);

@override
String toString() {
  return 'DaemonEvent.peerDiscovered(peerId: $peerId, name: $name, ip: $ip, port: $port)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_PeerDiscoveredCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_PeerDiscoveredCopyWith(DaemonEvent_PeerDiscovered value, $Res Function(DaemonEvent_PeerDiscovered) _then) = _$DaemonEvent_PeerDiscoveredCopyWithImpl;
@useResult
$Res call({
 String peerId, String name, String ip, int port
});




}
/// @nodoc
class _$DaemonEvent_PeerDiscoveredCopyWithImpl<$Res>
    implements $DaemonEvent_PeerDiscoveredCopyWith<$Res> {
  _$DaemonEvent_PeerDiscoveredCopyWithImpl(this._self, this._then);

  final DaemonEvent_PeerDiscovered _self;
  final $Res Function(DaemonEvent_PeerDiscovered) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,Object? name = null,Object? ip = null,Object? port = null,}) {
  return _then(DaemonEvent_PeerDiscovered(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class DaemonEvent_PeerLost extends DaemonEvent {
  const DaemonEvent_PeerLost({required this.peerId}): super._();
  

 final  String peerId;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_PeerLostCopyWith<DaemonEvent_PeerLost> get copyWith => _$DaemonEvent_PeerLostCopyWithImpl<DaemonEvent_PeerLost>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_PeerLost&&(identical(other.peerId, peerId) || other.peerId == peerId));
}


@override
int get hashCode => Object.hash(runtimeType,peerId);

@override
String toString() {
  return 'DaemonEvent.peerLost(peerId: $peerId)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_PeerLostCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_PeerLostCopyWith(DaemonEvent_PeerLost value, $Res Function(DaemonEvent_PeerLost) _then) = _$DaemonEvent_PeerLostCopyWithImpl;
@useResult
$Res call({
 String peerId
});




}
/// @nodoc
class _$DaemonEvent_PeerLostCopyWithImpl<$Res>
    implements $DaemonEvent_PeerLostCopyWith<$Res> {
  _$DaemonEvent_PeerLostCopyWithImpl(this._self, this._then);

  final DaemonEvent_PeerLost _self;
  final $Res Function(DaemonEvent_PeerLost) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,}) {
  return _then(DaemonEvent_PeerLost(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_TransferProgress extends DaemonEvent {
  const DaemonEvent_TransferProgress({required this.transferId, required this.bytesTransferred, required this.totalBytes, required this.speed}): super._();
  

 final  String transferId;
 final  BigInt bytesTransferred;
 final  BigInt totalBytes;
 final  double speed;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_TransferProgressCopyWith<DaemonEvent_TransferProgress> get copyWith => _$DaemonEvent_TransferProgressCopyWithImpl<DaemonEvent_TransferProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_TransferProgress&&(identical(other.transferId, transferId) || other.transferId == transferId)&&(identical(other.bytesTransferred, bytesTransferred) || other.bytesTransferred == bytesTransferred)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.speed, speed) || other.speed == speed));
}


@override
int get hashCode => Object.hash(runtimeType,transferId,bytesTransferred,totalBytes,speed);

@override
String toString() {
  return 'DaemonEvent.transferProgress(transferId: $transferId, bytesTransferred: $bytesTransferred, totalBytes: $totalBytes, speed: $speed)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_TransferProgressCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_TransferProgressCopyWith(DaemonEvent_TransferProgress value, $Res Function(DaemonEvent_TransferProgress) _then) = _$DaemonEvent_TransferProgressCopyWithImpl;
@useResult
$Res call({
 String transferId, BigInt bytesTransferred, BigInt totalBytes, double speed
});




}
/// @nodoc
class _$DaemonEvent_TransferProgressCopyWithImpl<$Res>
    implements $DaemonEvent_TransferProgressCopyWith<$Res> {
  _$DaemonEvent_TransferProgressCopyWithImpl(this._self, this._then);

  final DaemonEvent_TransferProgress _self;
  final $Res Function(DaemonEvent_TransferProgress) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? transferId = null,Object? bytesTransferred = null,Object? totalBytes = null,Object? speed = null,}) {
  return _then(DaemonEvent_TransferProgress(
transferId: null == transferId ? _self.transferId : transferId // ignore: cast_nullable_to_non_nullable
as String,bytesTransferred: null == bytesTransferred ? _self.bytesTransferred : bytesTransferred // ignore: cast_nullable_to_non_nullable
as BigInt,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as BigInt,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class DaemonEvent_TransferComplete extends DaemonEvent {
  const DaemonEvent_TransferComplete({required this.transferId, required this.status}): super._();
  

 final  String transferId;
 final  String status;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_TransferCompleteCopyWith<DaemonEvent_TransferComplete> get copyWith => _$DaemonEvent_TransferCompleteCopyWithImpl<DaemonEvent_TransferComplete>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_TransferComplete&&(identical(other.transferId, transferId) || other.transferId == transferId)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,transferId,status);

@override
String toString() {
  return 'DaemonEvent.transferComplete(transferId: $transferId, status: $status)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_TransferCompleteCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_TransferCompleteCopyWith(DaemonEvent_TransferComplete value, $Res Function(DaemonEvent_TransferComplete) _then) = _$DaemonEvent_TransferCompleteCopyWithImpl;
@useResult
$Res call({
 String transferId, String status
});




}
/// @nodoc
class _$DaemonEvent_TransferCompleteCopyWithImpl<$Res>
    implements $DaemonEvent_TransferCompleteCopyWith<$Res> {
  _$DaemonEvent_TransferCompleteCopyWithImpl(this._self, this._then);

  final DaemonEvent_TransferComplete _self;
  final $Res Function(DaemonEvent_TransferComplete) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? transferId = null,Object? status = null,}) {
  return _then(DaemonEvent_TransferComplete(
transferId: null == transferId ? _self.transferId : transferId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_PairingRequest extends DaemonEvent {
  const DaemonEvent_PairingRequest({required this.peerId, required this.pin}): super._();
  

 final  String peerId;
 final  String pin;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_PairingRequestCopyWith<DaemonEvent_PairingRequest> get copyWith => _$DaemonEvent_PairingRequestCopyWithImpl<DaemonEvent_PairingRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_PairingRequest&&(identical(other.peerId, peerId) || other.peerId == peerId)&&(identical(other.pin, pin) || other.pin == pin));
}


@override
int get hashCode => Object.hash(runtimeType,peerId,pin);

@override
String toString() {
  return 'DaemonEvent.pairingRequest(peerId: $peerId, pin: $pin)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_PairingRequestCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_PairingRequestCopyWith(DaemonEvent_PairingRequest value, $Res Function(DaemonEvent_PairingRequest) _then) = _$DaemonEvent_PairingRequestCopyWithImpl;
@useResult
$Res call({
 String peerId, String pin
});




}
/// @nodoc
class _$DaemonEvent_PairingRequestCopyWithImpl<$Res>
    implements $DaemonEvent_PairingRequestCopyWith<$Res> {
  _$DaemonEvent_PairingRequestCopyWithImpl(this._self, this._then);

  final DaemonEvent_PairingRequest _self;
  final $Res Function(DaemonEvent_PairingRequest) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,Object? pin = null,}) {
  return _then(DaemonEvent_PairingRequest(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,pin: null == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_TransferOffer extends DaemonEvent {
  const DaemonEvent_TransferOffer({required this.peerId, required this.transferId, required this.fileName, required this.fileSize, this.thumbnail}): super._();
  

 final  String peerId;
 final  String transferId;
 final  String fileName;
 final  BigInt fileSize;
 final  String? thumbnail;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_TransferOfferCopyWith<DaemonEvent_TransferOffer> get copyWith => _$DaemonEvent_TransferOfferCopyWithImpl<DaemonEvent_TransferOffer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_TransferOffer&&(identical(other.peerId, peerId) || other.peerId == peerId)&&(identical(other.transferId, transferId) || other.transferId == transferId)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.thumbnail, thumbnail) || other.thumbnail == thumbnail));
}


@override
int get hashCode => Object.hash(runtimeType,peerId,transferId,fileName,fileSize,thumbnail);

@override
String toString() {
  return 'DaemonEvent.transferOffer(peerId: $peerId, transferId: $transferId, fileName: $fileName, fileSize: $fileSize, thumbnail: $thumbnail)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_TransferOfferCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_TransferOfferCopyWith(DaemonEvent_TransferOffer value, $Res Function(DaemonEvent_TransferOffer) _then) = _$DaemonEvent_TransferOfferCopyWithImpl;
@useResult
$Res call({
 String peerId, String transferId, String fileName, BigInt fileSize, String? thumbnail
});




}
/// @nodoc
class _$DaemonEvent_TransferOfferCopyWithImpl<$Res>
    implements $DaemonEvent_TransferOfferCopyWith<$Res> {
  _$DaemonEvent_TransferOfferCopyWithImpl(this._self, this._then);

  final DaemonEvent_TransferOffer _self;
  final $Res Function(DaemonEvent_TransferOffer) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,Object? transferId = null,Object? fileName = null,Object? fileSize = null,Object? thumbnail = freezed,}) {
  return _then(DaemonEvent_TransferOffer(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,transferId: null == transferId ? _self.transferId : transferId // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as BigInt,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class DaemonEvent_LogMessage extends DaemonEvent {
  const DaemonEvent_LogMessage({required this.level, required this.message}): super._();
  

 final  String level;
 final  String message;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_LogMessageCopyWith<DaemonEvent_LogMessage> get copyWith => _$DaemonEvent_LogMessageCopyWithImpl<DaemonEvent_LogMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_LogMessage&&(identical(other.level, level) || other.level == level)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,level,message);

@override
String toString() {
  return 'DaemonEvent.logMessage(level: $level, message: $message)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_LogMessageCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_LogMessageCopyWith(DaemonEvent_LogMessage value, $Res Function(DaemonEvent_LogMessage) _then) = _$DaemonEvent_LogMessageCopyWithImpl;
@useResult
$Res call({
 String level, String message
});




}
/// @nodoc
class _$DaemonEvent_LogMessageCopyWithImpl<$Res>
    implements $DaemonEvent_LogMessageCopyWith<$Res> {
  _$DaemonEvent_LogMessageCopyWithImpl(this._self, this._then);

  final DaemonEvent_LogMessage _self;
  final $Res Function(DaemonEvent_LogMessage) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? level = null,Object? message = null,}) {
  return _then(DaemonEvent_LogMessage(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_CredentialsGenerated extends DaemonEvent {
  const DaemonEvent_CredentialsGenerated({required this.pin, required this.sessionKey}): super._();
  

 final  String pin;
 final  String sessionKey;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_CredentialsGeneratedCopyWith<DaemonEvent_CredentialsGenerated> get copyWith => _$DaemonEvent_CredentialsGeneratedCopyWithImpl<DaemonEvent_CredentialsGenerated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_CredentialsGenerated&&(identical(other.pin, pin) || other.pin == pin)&&(identical(other.sessionKey, sessionKey) || other.sessionKey == sessionKey));
}


@override
int get hashCode => Object.hash(runtimeType,pin,sessionKey);

@override
String toString() {
  return 'DaemonEvent.credentialsGenerated(pin: $pin, sessionKey: $sessionKey)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_CredentialsGeneratedCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_CredentialsGeneratedCopyWith(DaemonEvent_CredentialsGenerated value, $Res Function(DaemonEvent_CredentialsGenerated) _then) = _$DaemonEvent_CredentialsGeneratedCopyWithImpl;
@useResult
$Res call({
 String pin, String sessionKey
});




}
/// @nodoc
class _$DaemonEvent_CredentialsGeneratedCopyWithImpl<$Res>
    implements $DaemonEvent_CredentialsGeneratedCopyWith<$Res> {
  _$DaemonEvent_CredentialsGeneratedCopyWithImpl(this._self, this._then);

  final DaemonEvent_CredentialsGenerated _self;
  final $Res Function(DaemonEvent_CredentialsGenerated) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pin = null,Object? sessionKey = null,}) {
  return _then(DaemonEvent_CredentialsGenerated(
pin: null == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as String,sessionKey: null == sessionKey ? _self.sessionKey : sessionKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_QrPayloadGenerated extends DaemonEvent {
  const DaemonEvent_QrPayloadGenerated({required this.payloadJson}): super._();
  

 final  String payloadJson;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_QrPayloadGeneratedCopyWith<DaemonEvent_QrPayloadGenerated> get copyWith => _$DaemonEvent_QrPayloadGeneratedCopyWithImpl<DaemonEvent_QrPayloadGenerated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_QrPayloadGenerated&&(identical(other.payloadJson, payloadJson) || other.payloadJson == payloadJson));
}


@override
int get hashCode => Object.hash(runtimeType,payloadJson);

@override
String toString() {
  return 'DaemonEvent.qrPayloadGenerated(payloadJson: $payloadJson)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_QrPayloadGeneratedCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_QrPayloadGeneratedCopyWith(DaemonEvent_QrPayloadGenerated value, $Res Function(DaemonEvent_QrPayloadGenerated) _then) = _$DaemonEvent_QrPayloadGeneratedCopyWithImpl;
@useResult
$Res call({
 String payloadJson
});




}
/// @nodoc
class _$DaemonEvent_QrPayloadGeneratedCopyWithImpl<$Res>
    implements $DaemonEvent_QrPayloadGeneratedCopyWith<$Res> {
  _$DaemonEvent_QrPayloadGeneratedCopyWithImpl(this._self, this._then);

  final DaemonEvent_QrPayloadGenerated _self;
  final $Res Function(DaemonEvent_QrPayloadGenerated) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? payloadJson = null,}) {
  return _then(DaemonEvent_QrPayloadGenerated(
payloadJson: null == payloadJson ? _self.payloadJson : payloadJson // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_SettingReported extends DaemonEvent {
  const DaemonEvent_SettingReported({required this.key, required this.value}): super._();
  

 final  String key;
 final  String value;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_SettingReportedCopyWith<DaemonEvent_SettingReported> get copyWith => _$DaemonEvent_SettingReportedCopyWithImpl<DaemonEvent_SettingReported>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_SettingReported&&(identical(other.key, key) || other.key == key)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,key,value);

@override
String toString() {
  return 'DaemonEvent.settingReported(key: $key, value: $value)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_SettingReportedCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_SettingReportedCopyWith(DaemonEvent_SettingReported value, $Res Function(DaemonEvent_SettingReported) _then) = _$DaemonEvent_SettingReportedCopyWithImpl;
@useResult
$Res call({
 String key, String value
});




}
/// @nodoc
class _$DaemonEvent_SettingReportedCopyWithImpl<$Res>
    implements $DaemonEvent_SettingReportedCopyWith<$Res> {
  _$DaemonEvent_SettingReportedCopyWithImpl(this._self, this._then);

  final DaemonEvent_SettingReported _self;
  final $Res Function(DaemonEvent_SettingReported) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? key = null,Object? value = null,}) {
  return _then(DaemonEvent_SettingReported(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_SessionCodeGenerated extends DaemonEvent {
  const DaemonEvent_SessionCodeGenerated({required this.code}): super._();
  

 final  String code;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_SessionCodeGeneratedCopyWith<DaemonEvent_SessionCodeGenerated> get copyWith => _$DaemonEvent_SessionCodeGeneratedCopyWithImpl<DaemonEvent_SessionCodeGenerated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_SessionCodeGenerated&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode => Object.hash(runtimeType,code);

@override
String toString() {
  return 'DaemonEvent.sessionCodeGenerated(code: $code)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_SessionCodeGeneratedCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_SessionCodeGeneratedCopyWith(DaemonEvent_SessionCodeGenerated value, $Res Function(DaemonEvent_SessionCodeGenerated) _then) = _$DaemonEvent_SessionCodeGeneratedCopyWithImpl;
@useResult
$Res call({
 String code
});




}
/// @nodoc
class _$DaemonEvent_SessionCodeGeneratedCopyWithImpl<$Res>
    implements $DaemonEvent_SessionCodeGeneratedCopyWith<$Res> {
  _$DaemonEvent_SessionCodeGeneratedCopyWithImpl(this._self, this._then);

  final DaemonEvent_SessionCodeGenerated _self;
  final $Res Function(DaemonEvent_SessionCodeGenerated) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,}) {
  return _then(DaemonEvent_SessionCodeGenerated(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_SignalingStarted extends DaemonEvent {
  const DaemonEvent_SignalingStarted({required this.id}): super._();
  

 final  String id;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_SignalingStartedCopyWith<DaemonEvent_SignalingStarted> get copyWith => _$DaemonEvent_SignalingStartedCopyWithImpl<DaemonEvent_SignalingStarted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_SignalingStarted&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'DaemonEvent.signalingStarted(id: $id)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_SignalingStartedCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_SignalingStartedCopyWith(DaemonEvent_SignalingStarted value, $Res Function(DaemonEvent_SignalingStarted) _then) = _$DaemonEvent_SignalingStartedCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$DaemonEvent_SignalingStartedCopyWithImpl<$Res>
    implements $DaemonEvent_SignalingStartedCopyWith<$Res> {
  _$DaemonEvent_SignalingStartedCopyWithImpl(this._self, this._then);

  final DaemonEvent_SignalingStarted _self;
  final $Res Function(DaemonEvent_SignalingStarted) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(DaemonEvent_SignalingStarted(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_CodeGenerated extends DaemonEvent {
  const DaemonEvent_CodeGenerated({required this.key, this.pin, required this.ip}): super._();
  

 final  String key;
 final  String? pin;
 final  String ip;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_CodeGeneratedCopyWith<DaemonEvent_CodeGenerated> get copyWith => _$DaemonEvent_CodeGeneratedCopyWithImpl<DaemonEvent_CodeGenerated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_CodeGenerated&&(identical(other.key, key) || other.key == key)&&(identical(other.pin, pin) || other.pin == pin)&&(identical(other.ip, ip) || other.ip == ip));
}


@override
int get hashCode => Object.hash(runtimeType,key,pin,ip);

@override
String toString() {
  return 'DaemonEvent.codeGenerated(key: $key, pin: $pin, ip: $ip)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_CodeGeneratedCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_CodeGeneratedCopyWith(DaemonEvent_CodeGenerated value, $Res Function(DaemonEvent_CodeGenerated) _then) = _$DaemonEvent_CodeGeneratedCopyWithImpl;
@useResult
$Res call({
 String key, String? pin, String ip
});




}
/// @nodoc
class _$DaemonEvent_CodeGeneratedCopyWithImpl<$Res>
    implements $DaemonEvent_CodeGeneratedCopyWith<$Res> {
  _$DaemonEvent_CodeGeneratedCopyWithImpl(this._self, this._then);

  final DaemonEvent_CodeGenerated _self;
  final $Res Function(DaemonEvent_CodeGenerated) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? key = null,Object? pin = freezed,Object? ip = null,}) {
  return _then(DaemonEvent_CodeGenerated(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,pin: freezed == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as String?,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_PeerDisconnected extends DaemonEvent {
  const DaemonEvent_PeerDisconnected({required this.peerId}): super._();
  

 final  String peerId;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_PeerDisconnectedCopyWith<DaemonEvent_PeerDisconnected> get copyWith => _$DaemonEvent_PeerDisconnectedCopyWithImpl<DaemonEvent_PeerDisconnected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_PeerDisconnected&&(identical(other.peerId, peerId) || other.peerId == peerId));
}


@override
int get hashCode => Object.hash(runtimeType,peerId);

@override
String toString() {
  return 'DaemonEvent.peerDisconnected(peerId: $peerId)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_PeerDisconnectedCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_PeerDisconnectedCopyWith(DaemonEvent_PeerDisconnected value, $Res Function(DaemonEvent_PeerDisconnected) _then) = _$DaemonEvent_PeerDisconnectedCopyWithImpl;
@useResult
$Res call({
 String peerId
});




}
/// @nodoc
class _$DaemonEvent_PeerDisconnectedCopyWithImpl<$Res>
    implements $DaemonEvent_PeerDisconnectedCopyWith<$Res> {
  _$DaemonEvent_PeerDisconnectedCopyWithImpl(this._self, this._then);

  final DaemonEvent_PeerDisconnected _self;
  final $Res Function(DaemonEvent_PeerDisconnected) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,}) {
  return _then(DaemonEvent_PeerDisconnected(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DaemonEvent_PeerConnected extends DaemonEvent {
  const DaemonEvent_PeerConnected({required this.peerId, required this.name, required this.address, required this.port}): super._();
  

 final  String peerId;
 final  String name;
 final  String address;
 final  int port;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_PeerConnectedCopyWith<DaemonEvent_PeerConnected> get copyWith => _$DaemonEvent_PeerConnectedCopyWithImpl<DaemonEvent_PeerConnected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_PeerConnected&&(identical(other.peerId, peerId) || other.peerId == peerId)&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address)&&(identical(other.port, port) || other.port == port));
}


@override
int get hashCode => Object.hash(runtimeType,peerId,name,address,port);

@override
String toString() {
  return 'DaemonEvent.peerConnected(peerId: $peerId, name: $name, address: $address, port: $port)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_PeerConnectedCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_PeerConnectedCopyWith(DaemonEvent_PeerConnected value, $Res Function(DaemonEvent_PeerConnected) _then) = _$DaemonEvent_PeerConnectedCopyWithImpl;
@useResult
$Res call({
 String peerId, String name, String address, int port
});




}
/// @nodoc
class _$DaemonEvent_PeerConnectedCopyWithImpl<$Res>
    implements $DaemonEvent_PeerConnectedCopyWith<$Res> {
  _$DaemonEvent_PeerConnectedCopyWithImpl(this._self, this._then);

  final DaemonEvent_PeerConnected _self;
  final $Res Function(DaemonEvent_PeerConnected) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,Object? name = null,Object? address = null,Object? port = null,}) {
  return _then(DaemonEvent_PeerConnected(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class DaemonEvent_IncomingChat extends DaemonEvent {
  const DaemonEvent_IncomingChat({required this.peerId, required this.text}): super._();


 final  String peerId;
 final  String text;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonEvent_IncomingChatCopyWith<DaemonEvent_IncomingChat> get copyWith => _$DaemonEvent_IncomingChatCopyWithImpl<DaemonEvent_IncomingChat>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonEvent_IncomingChat&&(identical(other.peerId, peerId) || other.peerId == peerId)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,peerId,text);

@override
String toString() {
  return 'DaemonEvent.incomingChat(peerId: $peerId, text: $text)';
}


}

/// @nodoc
abstract mixin class $DaemonEvent_IncomingChatCopyWith<$Res> implements $DaemonEventCopyWith<$Res> {
  factory $DaemonEvent_IncomingChatCopyWith(DaemonEvent_IncomingChat value, $Res Function(DaemonEvent_IncomingChat) _then) = _$DaemonEvent_IncomingChatCopyWithImpl;
@useResult
$Res call({
 String peerId, String text
});




}
/// @nodoc
class _$DaemonEvent_IncomingChatCopyWithImpl<$Res>
    implements $DaemonEvent_IncomingChatCopyWith<$Res> {
  _$DaemonEvent_IncomingChatCopyWithImpl(this._self, this._then);

  final DaemonEvent_IncomingChat _self;
  final $Res Function(DaemonEvent_IncomingChat) _then;

/// Create a copy of DaemonEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peerId = null,Object? text = null,}) {
  return _then(DaemonEvent_IncomingChat(
peerId: null == peerId ? _self.peerId : peerId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
