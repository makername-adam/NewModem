function main_5g_nr_modem
% main_5g_nr_modem
% Single-file 5G NR-Inspired Adaptive OFDM Image Modem in MATLAB

    clear; clc; close all;

    %% ----------------- USER PARAMETERS -----------------
    imgFile      = fullfile('images','campus.jpeg');   % adjust name if needed
    bitsPerFrame = 2048;              % TB length
    snrRange_dB  = 0:4:24;            % SNR points
    modSchemes   = [4 16 64];         % QPSK, 16QAM, 64QAM
    codeRates    = [1/2 3/4];         % simple repetition-based FEC
    Nfft         = 64;                % OFDM size
    cpLen        = 16;                % CP length
    chanType     = 'awgn';        % 'awgn' or 'rayleigh'
    dopplerHz    = 5;                 % Doppler (Hz) for Rayleigh
    harqMaxTx    = 2;                 % max HARQ attempts per block

    rng(1);                           % reproducible

    %% ----------------- PREPARE IMAGE & BITS -----------------
    [img, imgBits] = img_to_bits(imgFile);
    [txBlocks, numBlocks] = segment_bits(imgBits, bitsPerFrame);
    fprintf('Image bits: %d, blocks: %d\n', numel(imgBits), numBlocks);

    %% ----------------- RUN SIMULATIONS -----------------
    [resultsFixed, resultsAdaptive] = sim_fixed_and_adaptive( ...
        txBlocks, img, bitsPerFrame, snrRange_dB, ...
        Nfft, cpLen, chanType, dopplerHz, ...
        modSchemes, codeRates, harqMaxTx);

    %% ----------------- PLOT RESULTS -----------------
    plot_results_5g(resultsFixed, resultsAdaptive, snrRange_dB);

    disp('Done. Figures generated.');

end

%% =======================================================================
%%                          TOP-LEVEL SIMULATION
%% =======================================================================

function [resultsFixed, resultsAdaptive] = sim_fixed_and_adaptive( ...
    txBlocks, img, bitsPerFrame, snrRange_dB, ...
    Nfft, cpLen, chanType, dopplerHz, ...
    modSchemes, codeRates, harqMaxTx)

    numBlocks = size(txBlocks,2);
    noiseVarFromSNR = @(snr_dB) 10.^(-snr_dB/10);

    %% ---------- FIXED-SCHEME RESULTS ----------
    resultsFixed = struct([]);
    for m = 1:length(modSchemes)
        M     = modSchemes(m);
        rate  = 1/2;
        label = sprintf('Fixed-%dQAM-R12', M);

        ber  = zeros(size(snrRange_dB));
        psnrVals = zeros(size(snrRange_dB));
        thr  = zeros(size(snrRange_dB));

        fprintf('\n=== %s ===\n', label);

        for si = 1:length(snrRange_dB)
            snr_dB = snrRange_dB(si);
            bitErrs=0; bitTotal=0;
            txBitsAll=[]; rxBitsAll=[];
            tbSent=0; tbChanUses=0;

            for b = 1:numBlocks
                bits = txBlocks(:,b);
                txCount=0; success=false;

                while ~success && txCount < harqMaxTx
                    txCount = txCount+1;

                    bitsEnc = fec_encode(bits, rate);
                    sym     = qam_mod_bits(bitsEnc, M);
                    txSig   = ofdm_modulate(sym, Nfft, cpLen);
                    rxSig   = apply_channel(txSig, snr_dB, chanType, dopplerHz);

                    noiseVar = noiseVarFromSNR(snr_dB);
                    rxSym    = ofdm_demodulate(rxSig, Nfft, cpLen);
                    llr      = qam_demod_llr(rxSym, M, noiseVar);
                    bitsDec = fec_decode(llr, rate);

                    if numel(bitsDec) < numel(bits)
                        bitsDec = [bitsDec; zeros(numel(bits) - numel(bitsDec),1)];
                    else
                        bitsDec = bitsDec(1:numel(bits));
                    end


                    if any(bitsDec ~= bits)
                        success = false;
                    else
                        success = true;
                    end
                end

                txBitsAll = [txBitsAll; bits];    %#ok<AGROW>
                rxBitsAll = [rxBitsAll; bitsDec]; %#ok<AGROW>
                bitErrs   = bitErrs + sum(bits~=bitsDec);
                bitTotal  = bitTotal + numel(bits);
                tbSent    = tbSent + 1;
                tbChanUses= tbChanUses + txCount;
            end

            ber(si)      = bitErrs/bitTotal;
            imgRec       = bits_to_img(rxBitsAll, img);
            psnrVals(si) = psnr_calc(img, imgRec);
            thr(si)      = (bitsPerFrame*tbSent)/(tbChanUses*Nfft);

            fprintf('%s: SNR=%2d dB, BER=%.3e, PSNR=%.2f, Thr=%.2f\n',...
                label, snr_dB, ber(si), psnrVals(si), thr(si));
        end

        resultsFixed(m).label = label;
        resultsFixed(m).ber   = ber;
        resultsFixed(m).psnr  = psnrVals;
        resultsFixed(m).thr   = thr;
        resultsFixed(m).M     = M;
        resultsFixed(m).R     = rate;
    end

    %% ---------- ADAPTIVE MODEM ----------
    fprintf('\n=== Adaptive 5G-Style Modem ===\n');

    cfg.initialM    = 4;
    cfg.initialRate = 1/2;
    cfg.cqiWindow   = 10;
    cfg.targetBLER  = 0.1;
    cfg.Mlist       = modSchemes;
    cfg.Rlist       = codeRates;

    berA  = zeros(size(snrRange_dB));
    psnrA = zeros(size(snrRange_dB));
    thrA  = zeros(size(snrRange_dB));

    for si = 1:length(snrRange_dB)
        snr_dB = snrRange_dB(si);
        bitErrs=0; bitTotal=0;
        txBitsAll=[]; rxBitsAll=[];
        tbSent=0; tbChanUses=0;

        % reset controller state
        state.curM    = cfg.initialM;
        state.curRate = cfg.initialRate;
        state.histErr = -ones(cfg.cqiWindow,1);  % -1 = unused
        state.histIdx = 0;

        for b = 1:numBlocks
            bits = txBlocks(:,b);

            [M, rate, state] = adaptive_controller(state, cfg);
            txCount=0; success=false;

            while ~success && txCount < harqMaxTx
                txCount = txCount+1;

                bitsEnc = fec_encode(bits, rate);
                sym     = qam_mod_bits(bitsEnc, M);
                txSig   = ofdm_modulate(sym, Nfft, cpLen);
                rxSig   = apply_channel(txSig, snr_dB, chanType, dopplerHz);

                noiseVar = noiseVarFromSNR(snr_dB);
                rxSym    = ofdm_demodulate(rxSig, Nfft, cpLen);
                llr      = qam_demod_llr(rxSym, M, noiseVar);
                bitsDec = fec_decode(llr, rate);

                if numel(bitsDec) < numel(bits)
                    bitsDec = [bitsDec; zeros(numel(bits) - numel(bitsDec),1)];
                else
                    bitsDec = bitsDec(1:numel(bits));
                end

                blkErr = any(bitsDec ~= bits);
                state  = update_controller_state(state, cfg, blkErr);

                if ~blkErr
                    success = true;
                end
            end

            txBitsAll = [txBitsAll; bits];    %#ok<AGROW>
            rxBitsAll = [rxBitsAll; bitsDec]; %#ok<AGROW>
            bitErrs   = bitErrs + sum(bits~=bitsDec);
            bitTotal  = bitTotal + numel(bits);
            tbSent    = tbSent + 1;
            tbChanUses= tbChanUses + txCount;
        end

        berA(si)  = bitErrs/bitTotal;
        imgRec    = bits_to_img(rxBitsAll, img);
        psnrA(si) = psnr_calc(img, imgRec);
        thrA(si)  = (bitsPerFrame*tbSent)/(tbChanUses*Nfft);

        fprintf('Adaptive: SNR=%2d dB, BER=%.3e, PSNR=%.2f, Thr=%.2f\n',...
            snr_dB, berA(si), psnrA(si), thrA(si));
    end

    resultsAdaptive.label = 'Adaptive';
    resultsAdaptive.ber   = berA;
    resultsAdaptive.psnr  = psnrA;
    resultsAdaptive.thr   = thrA;
end

%% =======================================================================
%%                       ADAPTIVE CONTROLLER HELPERS
%% =======================================================================

function [M, rate, state] = adaptive_controller(state, cfg)
    M    = state.curM;
    rate = state.curRate;

    valid = state.histErr(state.histErr>=0);
    if isempty(valid)
        estBLER = cfg.targetBLER;
    else
        estBLER = mean(valid);
    end

    if estBLER > 2*cfg.targetBLER
        [M, rate] = step_mcs(M, rate, cfg, -1); % more robust
    elseif estBLER < 0.5*cfg.targetBLER
        [M, rate] = step_mcs(M, rate, cfg, +1); % more aggressive
    end

    state.curM    = M;
    state.curRate = rate;
end

function state = update_controller_state(state, cfg, blkErr)
    state.histIdx = state.histIdx + 1;
    if state.histIdx > cfg.cqiWindow
        state.histIdx = 1;
    end
    state.histErr(state.histIdx) = blkErr;
end

function [Mnew, Rnew] = step_mcs(M, R, cfg, direction)
    combos = [];
    for i = 1:length(cfg.Mlist)
        for j = 1:length(cfg.Rlist)
            combos = [combos; cfg.Mlist(i) cfg.Rlist(j)]; %#ok<AGROW>
        end
    end
    se = log2(combos(:,1)).*combos(:,2);
    [~, idxOrder] = sort(se);
    combos = combos(idxOrder,:);

    idx = find(combos(:,1)==M & combos(:,2)==R, 1);
    if isempty(idx); idx = 1; end
    idxNew = max(1, min(size(combos,1), idx+direction));

    Mnew = combos(idxNew,1);
    Rnew = combos(idxNew,2);
end

%% =======================================================================
%%                              HELPERS
%% =======================================================================

function [img, bits] = img_to_bits(filename)
    img = imread(filename);
    if size(img,3) == 3
        img = rgb2gray(img);
    end
    imgVec = img(:);                       % uint8
    bits   = de2bi(imgVec, 8, 'left-msb').';
    bits   = bits(:);
end

function imgRec = bits_to_img(bits, origImg)
    nBytes = ceil(numel(bits)/8);
    bits   = [bits(:); zeros(nBytes*8 - numel(bits),1)];
    bytes  = bi2de(reshape(bits, 8, []).', 'left-msb');
    imgRec = reshape(uint8(bytes(1:numel(origImg))), size(origImg));
end

function [blocks, numBlocks] = segment_bits(bits, bitsPerFrame)
    bits = bits(:);
    numBlocks = ceil(numel(bits)/bitsPerFrame);
    padded    = [bits; zeros(numBlocks*bitsPerFrame - numel(bits),1)];
    blocks    = reshape(padded, bitsPerFrame, numBlocks);
end

function txSig = ofdm_modulate(sym, Nfft, cpLen)
    numSym   = length(sym);
    numOfdm  = ceil(numSym / Nfft);
    symPad   = [sym; zeros(numOfdm*Nfft-numSym,1)];
    symMat   = reshape(symPad, Nfft, numOfdm);
    timeMat  = ifft(symMat, Nfft, 1);
    cp       = timeMat(end-cpLen+1:end, :);
    txMat    = [cp; timeMat];
    txSig    = txMat(:);
end

function [rxSym] = ofdm_demodulate(rxSig, Nfft, cpLen)
    symLen  = Nfft + cpLen;
    numOfdm = floor(length(rxSig)/symLen);
    rxMat   = reshape(rxSig(1:numOfdm*symLen), symLen, numOfdm);
    rxMat   = rxMat(cpLen+1:end, :);
    freqMat = fft(rxMat, Nfft, 1);
    rxSym   = freqMat(:);
end

function rxSig = apply_channel(txSig, snr_dB, chanType, dopplerHz)
    %#ok<INUSD>  % dopplerHz not used now
    % Simple channel: AWGN only (no Rayleigh object needed)
    rxSig = awgn(txSig, snr_dB, 'measured');
end

function bitsEnc = fec_encode(bits, rate)
    bits = bits(:);
    switch rate
        case 1/2
            bitsEnc = repelem(bits, 2);
        case 3/4
            rep  = repelem(bits, 2);
            mask = true(size(rep));
            mask(4:4:end) = false;
            bitsEnc = rep(mask);
        otherwise
            bitsEnc = bits;
    end
end

function bitsDec = fec_decode(llr, rate)
    switch rate
        case 1/2
            llr2   = reshape(llr, 2, []).';
            llrSum = sum(llr2,2);
            bitsDec = llrSum < 0;
        case 3/4
            N     = floor(numel(llr)/3);
            llr3  = reshape(llr(1:3*N), 3, []).';
            llrSum = sum(llr3,2);
            bitsDec = llrSum < 0;
        otherwise
            bitsDec = llr < 0;
    end
end

function sym = qam_mod_bits(bits, M)
    k = log2(M);
    bits = bits(:);
    if mod(numel(bits),k) ~= 0
        bits = [bits; zeros(k - mod(numel(bits),k),1)];
    end
    symbols = bi2de(reshape(bits, k, []).', 'left-msb');
    sym     = qammod(symbols, M, 'UnitAveragePower', true);
end

function llr = qam_demod_llr(rxSym, M, noiseVar)
    k = log2(M);
    symSet = qammod(0:M-1, M, 'UnitAveragePower', true);
    bitMap = de2bi(0:M-1, k, 'left-msb');
    llr = zeros(k*length(rxSym),1);

    for i = 1:length(rxSym)
        r  = rxSym(i);
        d2 = abs(r - symSet).^2;
        for b = 1:k
            idx0 = bitMap(:,b)==0;
            idx1 = bitMap(:,b)==1;
            llr((i-1)*k + b) = logsumexp(-d2(idx0)/noiseVar) - ...
                               logsumexp(-d2(idx1)/noiseVar);
        end
    end
end

function y = logsumexp(x)
    m = max(x);
    y = m + log(sum(exp(x-m)));
end

function val = psnr_calc(orig, rec)
    orig = double(orig); rec = double(rec);
    mse  = mean((orig(:)-rec(:)).^2);
    if mse == 0
        val = 99;
    else
        val = 10*log10(255^2 / mse);
    end
end

%% =======================================================================
%%                           PLOTTING
%% =======================================================================

function plot_results_5g(resultsFixed, resultsAdaptive, snrRange_dB)

    figure('Name','BER vs SNR','NumberTitle','off');
    hold on; grid on;
    for k = 1:length(resultsFixed)
        semilogy(snrRange_dB, resultsFixed(k).ber, '-o','LineWidth',1.5);
    end
    semilogy(snrRange_dB, resultsAdaptive.ber, '-s','LineWidth',1.8);
    xlabel('SNR (dB)'); ylabel('BER');
    legend({resultsFixed.label,resultsFixed(2).label,resultsFixed(3).label,...
            resultsAdaptive.label}, 'Location','southwest');
    title('BER vs SNR');

    figure('Name','PSNR vs SNR','NumberTitle','off');
    hold on; grid on;
    for k = 1:length(resultsFixed)
        plot(snrRange_dB, resultsFixed(k).psnr, '-o','LineWidth',1.5);
    end
    plot(snrRange_dB, resultsAdaptive.psnr, '-s','LineWidth',1.8);
    xlabel('SNR (dB)'); ylabel('PSNR (dB)');
    legend({resultsFixed.label,resultsFixed(2).label,resultsFixed(3).label,...
            resultsAdaptive.label}, 'Location','southeast');
    title('Image PSNR vs SNR');

    figure('Name','Throughput vs SNR','NumberTitle','off');
    hold on; grid on;
    for k = 1:length(resultsFixed)
        plot(snrRange_dB, resultsFixed(k).thr, '-o','LineWidth',1.5);
    end
    plot(snrRange_dB, resultsAdaptive.thr, '-s','LineWidth',1.8);
    xlabel('SNR (dB)'); ylabel('Throughput (bits / subcarrier-use)');
    legend({resultsFixed.label,resultsFixed(2).label,resultsFixed(3).label,...
            resultsAdaptive.label}, 'Location','southeast');
    title('Spectral Efficiency vs SNR');
end
