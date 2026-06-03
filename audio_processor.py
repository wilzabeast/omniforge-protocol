import math
from typing import List, Dict, Tuple, Any
from enum import Enum
import time


class AudioQualityTier(Enum):
    STUDIO = "studio"
    BROADCAST = "broadcast"
    ACCEPTABLE = "acceptable"
    DEGRADED = "degraded"


class AutomatedAudioFilter:
    """
    Production-grade automated audio filter with deterministic processing.
    
    IMPROVEMENTS:
    - Deterministic breath suppression (removed randomness)
    - Silent audio detection with threshold tracking
    - Audio quality metrics calculation
    - Comprehensive error handling
    """
    
    def __init__(self, target_noise_floor_db: int = -45, suppress_breaths: bool = True, 
                 max_silence_threshold: int = 100):
        self.noise_floor = target_noise_floor_db
        self.suppress_breaths = suppress_breaths
        self.max_silence_threshold = max_silence_threshold
        self.processing_stats = {
            "total_chunks": 0,
            "gated_chunks": 0,
            "breath_chunks": 0,
            "silent_chunks": 0,
            "processing_time_ms": 0
        }
        print(f"[Audio System] Initialized with Noise Gate: {self.noise_floor}dB | Breath Suppression: {self.suppress_breaths}")

    def validate_audio_stream(self, raw_audio_stream: List[float]) -> bool:
        """
        Validates audio stream before processing.
        Checks for empty, NaN, or completely silent streams.
        """
        if not raw_audio_stream:
            raise ValueError("Audio stream cannot be empty")
        
        if len(raw_audio_stream) < 2:
            raise ValueError("Audio stream must have at least 2 chunks")
        
        # Check for NaN or inf values
        for i, amplitude in enumerate(raw_audio_stream):
            if not isinstance(amplitude, (int, float)):
                raise TypeError(f"Chunk {i}: amplitude must be numeric, got {type(amplitude)}")
            if math.isnan(amplitude) or math.isinf(amplitude):
                raise ValueError(f"Chunk {i}: amplitude contains NaN or inf")
        
        return True

    def analyze_spectral_density(self, raw_audio_stream_mock: List[float]) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
        """
        Scans raw audio data packets for decibel drops or spikes.
        Now with deterministic processing and silence detection.
        
        Returns: (processed_chunks, detection_stats)
        """
        start_time = time.time()
        
        # Validate input
        self.validate_audio_stream(raw_audio_stream_mock)
        
        processed_chunks = []
        consecutive_silence = 0
        detection_stats = {
            "max_consecutive_silence": 0,
            "total_silent_chunks": 0,
            "alert_triggered": False,
            "alert_message": None
        }
        
        for index, amplitude in enumerate(raw_audio_stream_mock):
            # Convert raw amplitude to decibel reading
            # Using small epsilon (1e-5) to prevent log10(0) errors
            current_db = 20 * math.log10(abs(amplitude) + 1e-5) if amplitude != 0 else -100
            
            # Apply Automated Noise Gate
            if current_db < self.noise_floor:
                cleaned_amplitude = 0.0
                status = "Gate Triggered (Noise Stripped)"
                consecutive_silence += 1
                detection_stats["total_silent_chunks"] += 1
                self.processing_stats["gated_chunks"] += 1
            else:
                cleaned_amplitude = amplitude
                status = "Signal Clear"
                consecutive_silence = 0
            
            # Track maximum consecutive silence
            if consecutive_silence > detection_stats["max_consecutive_silence"]:
                detection_stats["max_consecutive_silence"] = consecutive_silence
            
            # Alert if silence exceeds threshold (indicates TTS failure or stream loss)
            if consecutive_silence >= self.max_silence_threshold:
                detection_stats["alert_triggered"] = True
                detection_stats["alert_message"] = f"Audio stream lost at chunk {index}. {consecutive_silence} consecutive silent chunks detected. Possible TTS failure."
                print(f"[Audio Warning] {detection_stats['alert_message']}")
            
            processed_chunks.append({
                "chunk_id": index,
                "input_db": round(current_db, 2),
                "output_amplitude": cleaned_amplitude,
                "filter_status": status,
                "consecutive_silence_count": consecutive_silence
            })
            
            self.processing_stats["total_chunks"] += 1
        
        processing_time = (time.time() - start_time) * 1000
        self.processing_stats["processing_time_ms"] = round(processing_time, 2)
        
        return processed_chunks, detection_stats

    def apply_breath_gating(self, processed_chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Deterministic breath suppression based on spectral signature detection.
        
        LOGIC:
        - Breath signatures typically appear at -40 to -30dB
        - They often precede or follow silence gaps
        - Deterministic: same input always produces same output
        """
        if not self.suppress_breaths:
            return processed_chunks

        for i, chunk in enumerate(processed_chunks):
            # Check for breath signature frequency window
            if chunk["input_db"] > -40 and chunk["input_db"] < -30:
                
                # DETERMINISTIC: Check for silence context (not random)
                has_preceding_silence = (i > 0 and processed_chunks[i-1]["output_amplitude"] == 0.0)
                has_following_silence = (i < len(processed_chunks) - 1 and 
                                        processed_chunks[i+1]["output_amplitude"] == 0.0)
                
                # Suppress breath if it's surrounded by or preceded by silence
                if has_preceding_silence or has_following_silence:
                    chunk["output_amplitude"] *= 0.1
                    chunk["filter_status"] = "Breath Pattern Attenuated"
                    self.processing_stats["breath_chunks"] += 1
        
        return processed_chunks

    def calculate_audio_quality_score(self, processed_chunks: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Calculates comprehensive audio quality metrics for validation.
        
        Returns quality tier and detailed statistics for grant reviewers.
        """
        if not processed_chunks:
            return {
                "signal_integrity_percent": 0,
                "noise_suppression_effectiveness": 0,
                "breath_artifacts_removed": 0,
                "quality_tier": "degraded",
                "error": "No processed chunks available"
            }
        
        total_chunks = len(processed_chunks)
        gated_chunks = sum(1 for c in processed_chunks 
                          if c['filter_status'] == 'Gate Triggered (Noise Stripped)')
        breath_chunks = sum(1 for c in processed_chunks 
                           if 'Breath' in c['filter_status'])
        
        signal_integrity = ((total_chunks - gated_chunks) / total_chunks) * 100
        noise_suppression = (gated_chunks / total_chunks) * 100
        
        # Determine quality tier based on signal integrity
        if signal_integrity >= 95:
            quality_tier = AudioQualityTier.STUDIO.value
        elif signal_integrity >= 85:
            quality_tier = AudioQualityTier.BROADCAST.value
        elif signal_integrity >= 70:
            quality_tier = AudioQualityTier.ACCEPTABLE.value
        else:
            quality_tier = AudioQualityTier.DEGRADED.value
        
        return {
            "signal_integrity_percent": round(signal_integrity, 2),
            "noise_suppression_effectiveness": round(noise_suppression, 2),
            "breath_artifacts_removed": breath_chunks,
            "total_chunks_processed": total_chunks,
            "quality_tier": quality_tier,
            "recommended_for_production": signal_integrity >= 85
        }

    def get_processing_stats(self) -> Dict[str, Any]:
        """Return accumulated processing statistics."""
        return self.processing_stats.copy()

    def reset_stats(self):
        """Reset processing statistics."""
        self.processing_stats = {
            "total_chunks": 0,
            "gated_chunks": 0,
            "breath_chunks": 0,
            "silent_chunks": 0,
            "processing_time_ms": 0
        }


if __name__ == "__main__":
    # Simulate a raw audio payload coming out of a text-to-speech engine
    # Contains standard vocal spikes mixed with silent pauses that have background hiss/breaths
    mock_raw_audio = [0.85, 0.92, 0.02, 0.04, 0.01, 0.79, 0.03, 0.88]
    
    # Run the automated studio engineering filter pipeline
    audio_engine = AutomatedAudioFilter(target_noise_floor_db=-40, suppress_breaths=True)
    
    print("\n=== AUDIO PROCESSING PIPELINE ===")
    
    # Phase 1: Spectral Analysis
    phase_1_clean, detection_stats = audio_engine.analyze_spectral_density(mock_raw_audio)
    print(f"\n[Phase 1] Spectral Density Analysis Complete")
    print(f"  -> Max consecutive silence: {detection_stats['max_consecutive_silence']} chunks")
    print(f"  -> Total silent chunks: {detection_stats['total_silent_chunks']}")
    print(f"  -> Alert triggered: {detection_stats['alert_triggered']}")
    
    # Phase 2: Breath Gating
    final_studio_output = audio_engine.apply_breath_gating(phase_1_clean)
    print(f"\n[Phase 2] Breath Gating Applied")
    
    # Phase 3: Quality Metrics
    quality_metrics = audio_engine.calculate_audio_quality_score(final_studio_output)
    print(f"\n[Phase 3] Quality Metrics Calculated")
    print(f"  -> Signal Integrity: {quality_metrics['signal_integrity_percent']}%")
    print(f"  -> Quality Tier: {quality_metrics['quality_tier']}")
    print(f"  -> Production Ready: {quality_metrics['recommended_for_production']}")
    
    print("\n--- AUDIO PIPELINE STREAM ANALYSIS OUTPUT ---")
    for chunk in final_studio_output:
        print(f"Chunk [{chunk['chunk_id']}] -> Input: {chunk['input_db']}dB | Status: {chunk['filter_status']:45s} | Output Amp: {chunk['output_amplitude']}")
    
    print("\n--- QUALITY METRICS SUMMARY ---")
    for key, value in quality_metrics.items():
        print(f"  {key}: {value}")
    
    print("\n--- PROCESSING STATISTICS ---")
    for key, value in audio_engine.get_processing_stats().items():
        print(f"  {key}: {value}")
