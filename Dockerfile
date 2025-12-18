FROM trailofbits/eth-security-toolbox:nightly

WORKDIR /analysis

COPY . .

CMD ["bash"]