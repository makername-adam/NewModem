clc;
clear all;
close all;
%%%%% TRANSMITTER   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
in=imread('peppers.png');    % image to be transmitted and matlab code should be in same directory
N=numel(in);
in2=reshape(in,N,1);
bin=de2bi(in2,'left-msb');
input=reshape(bin',numel(bin),1);
len=length(input);
%%%%% padding zeroes to input %%%
z=len;
while(rem(z,2) || rem(z,4)|| rem(z,6))
    z=z+1;
    input(z,1)=0;
end
input=double(input);
sym_qpsk = bi2de(reshape(input, 2, []).', 'left-msb');
y_qpsk=pskmod(sym_qpsk, 4, pi/4);
sym_16qam = bi2de(reshape(input, 4, []).', 'left-msb');
y_16qam=qammod(sym_16qam, 16, 'gray', 'UnitAveragePower', true);
sym_64qam = bi2de(reshape(input, 6, []).', 'left-msb');
y_64qam=qammod(sym_64qam, 64, 'gray', 'UnitAveragePower', true);
ifft_out_qpsk=ifft(y_qpsk);
ifft_out_16qam=ifft(y_16qam);
ifft_out_64qam=ifft(y_64qam);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SNR=10;          % SNR in dB
tx_qpsk=awgn(ifft_out_qpsk,SNR,'measured');
tx_16qam=awgn(ifft_out_16qam,SNR,'measured');
tx_64qam=awgn(ifft_out_64qam,SNR,'measured');
%%%%    RECEIVER  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
k_qpsk=fft(tx_qpsk);
k_16qam=fft(tx_16qam);
k_64qam=fft(tx_64qam);
sym_qpsk = pskdemod(k_qpsk, 4, pi/4);
l_qpsk = (de2bi(sym_qpsk, 2, 'left-msb'));
l_qpsk = reshape(l_qpsk.', [], 1);
l_qpsk = l_qpsk(:);
sym_16qam=qamdemod(k_16qam, 16, 'gray', 'UnitAveragePower', true);
l_16qam = de2bi(sym_16qam, 4, 'left-msb');
l_16qam = reshape(l_16qam.', [], 1);
l_16qam = l_16qam(:);
sym_64qam=qamdemod(k_64qam, 64, 'gray', 'UnitAveragePower', true);
l_64qam = de2bi(sym_64qam, 6, 'left-msb');
l_64qam = reshape(l_64qam.', [], 1);
l_64qam = l_64qam(:);
output_qpsk=uint8(l_qpsk);
output_16qam=uint8(l_16qam);
output_64qam=uint8(l_64qam);
output_qpsk=output_qpsk(1:len);
output_16qam=output_16qam(1:len);
output_64qam=output_64qam(1:len);
b1=reshape(output_qpsk,8,N)';
b2=reshape(output_16qam,8,N)';
b3=reshape(output_64qam,8,N)';
dec_qpsk=bi2de(b1,'left-msb');
dec_16qam=bi2de(b2,'left-msb');
dec_64qam=bi2de(b3,'left-msb');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
BER_qpsk=biterr(input,l_qpsk)/len
BER_16qam=biterr(input,l_16qam)/len
BER_64qam=biterr(input,l_64qam)/len
%%%% Received image data  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
im_qpsk=reshape(dec_qpsk(1:N),size(in,1),size(in,2),size(in,3));
im_16qam=reshape(dec_16qam(1:N),size(in,1),size(in,2),size(in,3));
im_64qam=reshape(dec_64qam(1:N),size(in,1),size(in,2),size(in,3));
figure;
subplot(231);
imshow(im_qpsk);title('QPSK');
subplot(232);
imshow(im_16qam);title('16QAM');
subplot(233);
imshow(im_64qam);title('64QAM');
subplot(234);
scatter(real(k_qpsk),imag(k_qpsk),10,'filled');title('Constellation of Received QPSK Signal');grid on;
subplot(235);
scatter(real(k_16qam),imag(k_16qam),10,'filled');title('Constellation of Received 16QAM Signal');grid on;
subplot(236);
scatter(real(k_64qam),imag(k_64qam),10,'filled');title('Constellation of Received 64QAM Signal');grid on;