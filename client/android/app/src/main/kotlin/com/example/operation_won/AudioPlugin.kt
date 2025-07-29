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
        
        // Generate E2EE key
        generateEncryptionKey()
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
            result.success(true)
            return
        }
        
        // Check permission
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) 
            != PackageManager.PERMISSION_GRANTED) {
            result.success(false)
            return
        }
        
        try {
            // Create AudioRecord instance
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                channelConfig,
                audioFormat,
                bufferSize
            )
            
            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                result.success(false)
                return
            }
            
            // Setup audio effects if Magic Mic is enabled
            if (magicMicEnabled) {
                setupAudioEffects()
            }
            
            audioRecord?.startRecording()
            isRecording = true
            
            // Start recording in background coroutine
            recordingJob = CoroutineScope(Dispatchers.IO).launch {
                recordAudio()
            }
            
            result.success(true)
        } catch (e: Exception) {
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
        val buffer = ByteArray(bufferSize)
        
        while (isRecording && audioRecord != null) {
            val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: 0
            
            if (bytesRead > 0) {
                // Apply E2EE encryption if key is available
                val dataToSend = if (encryptionKey != null) {
                    encryptAudioData(buffer.copyOf(bytesRead))
                } else {
                    buffer.copyOf(bytesRead)
                }
                
                // Send audio data to Flutter
                withContext(Dispatchers.Main) {
                    channel.invokeMethod("onAudioData", dataToSend)
                }
            }
        }
    }
    
    private fun stopRecording(result: Result? = null) {
        if (!isRecording) {
            result?.success(null)
            return
        }
        
        isRecording = false
        recordingJob?.cancel()
        
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        
        releaseAudioEffects()
        
        result?.success(null)
    }
    
    private fun startPlaying(result: Result) {
        if (isPlaying) {
            result.success(null)
            return
        }
        
        try {
            val outChannelConfig = AudioFormat.CHANNEL_OUT_MONO
            val outBufferSize = AudioTrack.getMinBufferSize(sampleRate, outChannelConfig, audioFormat)
            
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
            
            result.success(null)
        } catch (e: Exception) {
            result.error("PLAYBACK_ERROR", "Failed to start playback: ${e.message}", null)
        }
    }
    
    private fun stopPlaying(result: Result? = null) {
        if (!isPlaying) {
            result?.success(null)
            return
        }
        
        isPlaying = false
        
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
        
        result?.success(null)
    }
    
    private fun playAudioChunk(call: MethodCall, result: Result) {
        if (!isPlaying || audioTrack == null) {
            result.success(null)
            return
        }
        
        try {
            val audioData = call.arguments as ByteArray
            
            // Apply E2EE decryption if key is available
            val decryptedData = if (encryptionKey != null) {
                decryptAudioData(audioData)
            } else {
                audioData
            }
            
            if (decryptedData != null) {
                audioTrack?.write(decryptedData, 0, decryptedData.size)
            }
            
            result.success(null)
        } catch (e: Exception) {
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
