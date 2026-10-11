clc
clear
close all

% open files and get the sampling frequency 
[speech, Fs_speech] = audioread('audio/speech/Macmiller_quote.wav'); 
[music, Fs_music]   = audioread('audio/carriers/Piano_Chords.wav');

% we insure both files have the same sampling rate 
if Fs_speech ~= Fs_music
    error('Error: Sampling rates do not match. Please resample the files.');
end

Fs = Fs_speech; 

% if the audio is stereo, we average them into one to make them mono.
if size(speech, 2) > 1
    speech = mean(speech, 2);
end
if size(music, 2) > 1
    music = mean(music, 2);
end

% Volume Control
max_speech = max(abs(speech));
max_music  = max(abs(music));

if max_speech > 0
    speech = speech / max_speech;
end

if max_music > 0
    music = music / max_music;
end

speech = speech * 0.95;
music  = music * 0.95;

% we make sure its a column vector
speech = speech(:);
music = music(:);

% zero-padding the signals to make thems the same length
len_speech = length(speech);
len_music  = length(music);
max_len    = max(len_speech, len_music);

speech = [speech; zeros(max_len - len_speech, 1)];
music = [music;  zeros(max_len - len_music,  1)];

% system parameters, to change and see the effect
M = 2048; % should be a power of 2 to make the fft done behind the scenes in the xcorr function faster  .          
R = M / 8; 

% LPC-orders, I used 2 orders as there are 2 LPCs one for whitening the
% guitar and the other is for shaping the guitar sound according to the
% formants of the voice
p_speech = 44 ; % using rule of sum for the speech mentioned in slides
p_music = 95; % this we experiment and see

% OLA padding (based on N = L + M - 1)
tail_FIR = p_music; 
tail_IIR = R; % as this is an IIR filter we didtn't use p_speech 
total_tail = tail_FIR + tail_IIR ;

% output array
output_buffer = zeros(max_len + total_tail, 1);

% generate a window 
w = hamming(M);

% loop through the audio chunks, jumping by the hop size R and applyng the
% Cross-Synthesis and OLA concepts

for idx = 1 : R : (max_len - M)
    
    % the sample range for the current chunk
    frame_range = idx : (idx + M - 1);
    
    % Extract and window
    speech_frame = speech(frame_range) .* w;
    music_frame  = music(frame_range)  .* w;
    
    % Apply zero-padding BEFORE filtering ---
    padded_music_frame = [music_frame; zeros(total_tail, 1)];
    
    % Whiten the instrument
    % analyze the unpadded frame
    [r_music, ~] = xcorr(music_frame);
    center_m = ceil(length(r_music) / 2);
    r_pos_music = r_music(center_m : (center_m + p_music));
    a_music = levinson(r_pos_music, p_music);
    
    % apply the whitening filter to the padded frame
    e_music = filter(a_music, 1, padded_music_frame); 
    
    % extract the vocal shape
    [r_speech, ~] = xcorr(speech_frame);
    center_s = ceil(length(r_speech) / 2);
    r_pos_speech = r_speech(center_s : (center_s + p_speech));
    a_speech = levinson(r_pos_speech, p_speech);
    
    % apply shaping filter to the residual
    synthesized_frame = filter(1, a_speech, e_music);

% % ====================================================================
%     % plot of the processing of the first frame
%     figure('Name', 'Stage by Stage Spectral Plot');
%     Nfft_plot = 2048;
%     f_axis = linspace(0, Fs/2, Nfft_plot/2);
% 
%     % Calculate the spectra
%     mag_speech   = 20*log10(abs(fft(speech_frame, Nfft_plot)) + eps); 
%     mag_music    = 20*log10(abs(fft(music_frame, Nfft_plot)) + eps);
%     mag_whitened = 20*log10(abs(fft(e_music(1:M), Nfft_plot)) + eps);
%     mag_synth    = 20*log10(abs(fft(synthesized_frame(1:M), Nfft_plot)) + eps);
% 
%     % 1. Original Speech
%     subplot(4,1,1);
%     plot(f_axis, mag_speech(1:Nfft_plot/2), 'm'); % Magenta for speech
%     title('1. Original Speech Signal');
%     ylabel('Magnitude (dB)'); 
%     xlim([0 8000]); grid on;
% 
%     % 2. Original Music 
%     subplot(4,1,2);
%     plot(f_axis, mag_music(1:Nfft_plot/2), 'b');
%     title('2. Original Music Signal');
%     ylabel('Magnitude (dB)'); 
%     xlim([0 8000]); grid on;
% 
%     % 3. Whitened Music (The Residual)
%     subplot(4,1,3);
%     plot(f_axis, mag_whitened(1:Nfft_plot/2), 'g');
%     title('3. Whitened Music');
%     ylabel('Magnitude (dB)'); 
%     xlim([0 8000]); grid on;
% 
%     % 4. Shaped Output (Cross-Synthesis)
%     subplot(4,1,4);
%     plot(f_axis, mag_synth(1:Nfft_plot/2), 'r');
%     title('4. Shaped Output');
%     xlabel('Frequency (Hz)'); 
%     ylabel('Magnitude (dB)'); 
%     xlim([0 8000]); grid on;
%     % ====================================================================
    % OLA
    % define the indices for the buffer
    ola_idxs = idx : (idx + M + total_tail - 1);
    
    % Add the new frame to the buffer
    output_buffer(ola_idxs) = output_buffer(ola_idxs) + synthesized_frame;
    % break; % This break is for the plot
    
end


%% Normalize and export

max_val = max(abs(output_buffer));

if max_val > 0
    output_buffer = output_buffer / max_val;
end

output_buffer = output_buffer * 0.95;

audiowrite('audio/carriers/Macmiller_quote_plus_Pianochords.wav', output_buffer, Fs);
