package com.example.operation_won

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.*
import android.media.audiofx.*
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.nio.ByteBuffer
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec
import kotlin.math.min

class AudioPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    
    // Audio recording
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingJob: Job? = null
    
    // Audio playback
    private var audioTrack: AudioTrack? = null
    private var isPlaying = false
    
    // Audio effects for "Magic Mic"
    private var noiseSuppressor: NoiseSuppressor? = null
    private var automaticGainControl: AutomaticGainControl? = null
    
    // Audio configuration
    private var sampleRate = 48000
    private var channelConfig = AudioFormat.CHANNEL_IN_MONO
    private var audioFormat = AudioFormat.ENCODING_PCM_16BIT
    private var bufferSize = 0
    
    // E2EE
    private var encryptionKey: SecretKey? = null
    private val secureRandom = SecureRandom()
    
    // Magic Mic enabled flag
    private var magicMicEnabled = false
    
    companion object {
        private const val CHANNEL = "operation_won/audio"
        private const val PERMISSION_REQUEST_CODE = 1001
        
        // E2EE constants
        private const val AES_TRANSFORMATION = "AES/CBC/PKCS5Padding"
        private const val AES_KEY_LENGTH = 256
        private const val IV_LENGTH = 16
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        
        // Initialize buffer size
        bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
            bufferSize = sampleRate * 2 // 1 second buffer as fallback
        }
        
        // TEMPORARILY DISABLE E2EE - Generate E2EE key
        // generateEncryptionKey()
        android.util.Log.d("AudioPlugin", "onAttachedToEngine: E2EE disabled for testing")
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stopRecording()
        stopPlaying()
        releaseAudioEffects()
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "requestMicrophonePermission" -> requestMicrophonePermission(result)
            "startRecording" -> startRecording(result)
            "stopRecording" -> stopRecording(result)
            "playAudioChunk" -> playAudioChunk(call, result)
            "startPlaying" -> startPlaying(result)
            "stopPlaying" -> stopPlaying(result)
            "setAudioConfig" -> setAudioConfig(call, result)
            "setMagicMicEnabled" -> setMagicMicEnabled(call, result)
            "generateE2EEKey" -> generateE2EEKey(result)
            "setE2EEKey" -> setE2EEKey(call, result)
            "encryptAudioData" -> {
                // E2EE disabled for testing - return unencrypted data
                android.util.Log.d("AudioPlugin", "encryptAudioData: E2EE disabled, returning unencrypted data")
                result.success(call.arguments)
            }
            "decryptAudioData" -> {
                // E2EE disabled for testing - return data as-is
                android.util.Log.d("AudioPlugin", "decryptAudioData: E2EE disabled, returning data as-is")
                result.success(call.arguments)
            }
            else -> result.notImplemented()
        }
    }
    
    private fun requestMicrophonePermission(result: Result) {
        val hasPermission = ContextCompat.checkSelfPermission(
            context, 
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        
        result.success(hasPermission)
    }
    
    private fun startRecording(result: Result) {
        if (isRecording) {
            android.util.Log.d("AudioPlugin", "startRecording: Already recording")
            result.success(true)
            return
        }
        
        // Check permission
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) 
            != PackageManager.PERMISSION_GRANTED) {
            android.util.Log.w("AudioPlugin", "startRecording: Microphone permission not granted")
            result.success(false)
            return
        }
        
        try {
            android.util.Log.d("AudioPlugin", "startRecording: Creating AudioRecord with sampleRate=$sampleRate, bufferSize=$bufferSize")
            
            // Create AudioRecord instance
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                channelConfig,
                audioFormat,
                bufferSize
            )
            
            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                android.util.Log.e("AudioPlugin", "startRecording: AudioRecord failed to initialize, state=${audioRecord?.state}")
                result.success(false)
                return
            }
            
            android.util.Log.d("AudioPlugin", "startRecording: AudioRecord initialized successfully")
            
            // Setup audio effects if Magic Mic is enabled
            if (magicMicEnabled) {
                android.util.Log.d("AudioPlugin", "startRecording: Setting up Magic Mic audio effects")
                setupAudioEffects()
            }
            
            audioRecord?.startRecording()
            isRecording = true
            
            android.util.Log.d("AudioPlugin", "startRecording: AudioRecord.startRecording() called")
            
            // Start recording in background coroutine
            recordingJob = CoroutineScope(Dispatchers.IO).launch {
                recordAudio()
            }
            
            android.util.Log.d("AudioPlugin", "startRecording: Recording coroutine started")
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("AudioPlugin", "startRecording: Exception occurred", e)
            result.error("RECORDING_ERROR", "Failed to start recording: ${e.message}", null)
        }
    }
    
    private fun setupAudioEffects() {
        try {
            val audioSessionId = audioRecord?.audioSessionId ?: return
            
            // Noise Suppressor
            if (NoiseSuppressor.isAvailable()) {
                noiseSuppressor = NoiseSuppressor.create(audioSessionId)
                noiseSuppressor?.enabled = true
            }
            
            // Automatic Gain Control
            if (AutomaticGainControl.isAvailable()) {
                automaticGainControl = AutomaticGainControl.create(audioSessionId)
                automaticGainControl?.enabled = true
            }
        } catch (e: Exception) {
            // Effects not available on this device
        }
    }
    
    private fun releaseAudioEffects() {
        noiseSuppressor?.release()
        noiseSuppressor = null
        automaticGainControl?.release()
        automaticGainControl = null
    }
    
    private suspend fun recordAudio() {
        android.util.Log.d("AudioPlugin", "recordAudio: Starting audio recording loop")
        val buffer = ByteArray(bufferSize)
        var totalBytesRead = 0
        var chunksProcessed = 0
        
        while (isRecording && audioRecord != null) {
            val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: 0
            
            if (bytesRead > 0) {
                totalBytesRead += bytesRead
                chunksProcessed++
                
                // Log every 50 chunks to avoid spam
                if (chunksProcessed % 50 == 0) {
                    android.util.Log.d("AudioPlugin", "recordAudio: Processed $chunksProcessed chunks, total bytes: $totalBytesRead")
                }
                
                // E2EE disabled for testing - send data unencrypted
                val dataToSend = buffer.copyOf(bytesRead)
                android.util.Log.d("AudioPlugin", "recordAudio: E2EE disabled, sending ${dataToSend.size} bytes unencrypted")
                
                // Send audio data to Flutter
                withContext(Dispatchers.Main) {
                    try {
                        channel.invokeMethod("onAudioData", dataToSend)
                        if (chunksProcessed <= 5) {
                            android.util.Log.d("AudioPlugin", "recordAudio: Sent audio chunk #$chunksProcessed to Flutter (${dataToSend.size} bytes)")
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("AudioPlugin", "recordAudio: Failed to send audio data to Flutter", e)
                    }
                }
            } else if (bytesRead < 0) {
                android.util.Log.w("AudioPlugin", "recordAudio: AudioRecord.read() returned error code: $bytesRead")
            }
        }
        
        android.util.Log.d("AudioPlugin", "recordAudio: Recording loop ended. Total chunks: $chunksProcessed, total bytes: $totalBytesRead")
    }
    
    private fun stopRecording(result: Result? = null) {
        if (!isRecording) {
            android.util.Log.d("AudioPlugin", "stopRecording: Not currently recording")
            result?.success(null)
            return
        }
        
        android.util.Log.d("AudioPlugin", "stopRecording: Stopping audio recording")
        isRecording = false
        recordingJob?.cancel()
        
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        
        releaseAudioEffects()
        
        android.util.Log.d("AudioPlugin", "stopRecording: Audio recording stopped and released")
        result?.success(null)
    }
    
    private fun startPlaying(result: Result) {
        if (isPlaying) {
            android.util.Log.d("AudioPlugin", "startPlaying: Already playing")
            result.success(null)
            return
        }
        
        try {
            android.util.Log.d("AudioPlugin", "startPlaying: Initializing AudioTrack with sampleRate=$sampleRate")
            val outChannelConfig = AudioFormat.CHANNEL_OUT_MONO
            val outBufferSize = AudioTrack.getMinBufferSize(sampleRate, outChannelConfig, audioFormat)
            android.util.Log.d("AudioPlugin", "startPlaying: Buffer size calculated: $outBufferSize")
            
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(audioFormat)
                        .setSampleRate(sampleRate)
                        .setChannelMask(outChannelConfig)
                        .build()
                )
                .setBufferSizeInBytes(outBufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            
            audioTrack?.play()
            isPlaying = true
            
            android.util.Log.d("AudioPlugin", "startPlaying: AudioTrack started successfully")
            result.success(null)
        } catch (e: Exception) {
            android.util.Log.e("AudioPlugin", "startPlaying: Failed to start playback", e)
            result.error("PLAYBACK_ERROR", "Failed to start playback: ${e.message}", null)
        }
    }
    
    private fun stopPlaying(result: Result? = null) {
        if (!isPlaying) {
            android.util.Log.d("AudioPlugin", "stopPlaying: Not currently playing")
            result?.success(null)
            return
        }
        
        android.util.Log.d("AudioPlugin", "stopPlaying: Stopping AudioTrack")
        isPlaying = false
        
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
        
        android.util.Log.d("AudioPlugin", "stopPlaying: AudioTrack stopped and released")
        result?.success(null)
    }
    
    private fun playAudioChunk(call: MethodCall, result: Result) {
        if (!isPlaying || audioTrack == null) {
            android.util.Log.d("AudioPlugin", "playAudioChunk: Cannot play - isPlaying=$isPlaying, audioTrack=${audioTrack != null}")
            result.success(null)
            return
        }
        
        try {
            val audioData = call.arguments as ByteArray
            android.util.Log.d("AudioPlugin", "playAudioChunk: Received ${audioData.size} bytes")
            
            // E2EE disabled for testing - use audio data directly
            val dataToPlay = audioData
            android.util.Log.d("AudioPlugin", "playAudioChunk: E2EE disabled, playing data directly (${dataToPlay.size} bytes)")
            
            val bytesWritten = audioTrack?.write(dataToPlay, 0, dataToPlay.size)
            android.util.Log.d("AudioPlugin", "playAudioChunk: Wrote $bytesWritten bytes to AudioTrack")
            
            result.success(null)
        } catch (e: Exception) {
            android.util.Log.e("AudioPlugin", "playAudioChunk: Error playing audio", e)
            result.error("PLAYBACK_ERROR", "Failed to play audio chunk: ${e.message}", null)
        }
    }
    
    private fun setAudioConfig(call: MethodCall, result: Result) {
        val arguments = call.arguments as Map<String, Any>
        
        sampleRate = arguments["sampleRate"] as? Int ?: 48000
        val channels = arguments["channels"] as? Int ?: 1
        val bitRate = arguments["bitRate"] as? Int ?: 64000
        
        channelConfig = if (channels == 1) {
            AudioFormat.CHANNEL_IN_MONO
        } else {
            AudioFormat.CHANNEL_IN_STEREO
        }
        
        // Recalculate buffer size
        bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
            bufferSize = sampleRate * 2
        }
        
        result.success(null)
    }
    
    private fun setMagicMicEnabled(call: MethodCall, result: Result) {
        magicMicEnabled = call.arguments as Boolean
        result.success(null)
    }
    
    // E2EE Methods
    private fun generateEncryptionKey() {
        try {
            val keyGenerator = KeyGenerator.getInstance("AES")
            keyGenerator.init(AES_KEY_LENGTH)
            encryptionKey = keyGenerator.generateKey()
        } catch (e: Exception) {
            // Key generation failed
        }
    }
    
    private fun generateE2EEKey(result: Result) {
        generateEncryptionKey()
        val keyBytes = encryptionKey?.encoded
        result.success(keyBytes)
    }
    
    private fun setE2EEKey(call: MethodCall, result: Result) {
        try {
            val keyBytes = call.arguments as ByteArray
            encryptionKey = SecretKeySpec(keyBytes, "AES")
            result.success(true)
        } catch (e: Exception) {
            result.error("E2EE_ERROR", "Failed to set encryption key: ${e.message}", null)
        }
    }
    
    private fun encryptAudioData(data: ByteArray): ByteArray? {
        return try {
            val cipher = Cipher.getInstance(AES_TRANSFORMATION)
            val iv = ByteArray(IV_LENGTH)
            secureRandom.nextBytes(iv)
            val ivSpec = IvParameterSpec(iv)
            
            cipher.init(Cipher.ENCRYPT_MODE, encryptionKey, ivSpec)
            val encryptedData = cipher.doFinal(data)
            
            // Prepend IV to encrypted data
            iv + encryptedData
        } catch (e: Exception) {
            null
        }
    }
    
    private fun decryptAudioData(encryptedData: ByteArray): ByteArray? {
        return try {
            if (encryptedData.size < IV_LENGTH) return null
            
            val iv = encryptedData.copyOfRange(0, IV_LENGTH)
            val cipherText = encryptedData.copyOfRange(IV_LENGTH, encryptedData.size)
            
            val cipher = Cipher.getInstance(AES_TRANSFORMATION)
            val ivSpec = IvParameterSpec(iv)
            
            cipher.init(Cipher.DECRYPT_MODE, encryptionKey, ivSpec)
            cipher.doFinal(cipherText)
        } catch (e: Exception) {
            null
        }
    }
}
