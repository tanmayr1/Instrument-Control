classdef Oscilloscope < handle
    % Oscilloscope Class to interface with a Keysight Oscilloscope using visadev library
    
    properties (Access = private)
        VisaResource % VISA resource name
        Device % visadev object
    end
    
    methods
        % Constructor
        function obj = Oscilloscope(visaResource)
            % Initialize the oscilloscope object
            obj.VisaResource = visaResource;
            try
                obj.Device = visadev(visaResource);
                configureTerminator(obj.Device, "LF");
                disp('Oscilloscope connected successfully.');
            catch ME
                error('Failed to connect to the oscilloscope: %s', ME.message);
            end
        end
        
        % Function to write a command to the oscilloscope
        function writeCommand(obj, command)
            try
                writeline(obj.Device, command);
            catch ME
                error('Failed to write command: %s', ME.message);
            end
        end
        
        % Function to read a response from the oscilloscope
        function response = readResponse(obj)
            try
                response = readline(obj.Device);
            catch ME
                error('Failed to read response: %s', ME.message);
            end
        end
        
        % Function to query the oscilloscope (write and read)
        function response = query(obj, command)
            try
                response = writeread(obj.Device, command);
            catch ME
                error('Failed to query the oscilloscope: %s', ME.message);
            end
        end
        
        % Destructor
        function delete(obj)
            % Clean up the connection
            if ~isempty(obj.Device)
                clear obj.Device;
                disp('Oscilloscope connection closed.');
            end
        end

        function [time, voltage] = recordWaveform(obj, channel, duration)
            % recordWaveform - Records waveform data from a Tektronix DPO2014
            % channel : string like 'CH1'
            % duration : duration in seconds to wait before reading data
            
            if nargin < 3
                error("Specify channel and duration.");
            end
        
            % Stop and clear any previous acquisitions
            obj.writeCommand('STOP');
            obj.writeCommand('CLEAR');
        
            % Set data source
            obj.writeCommand(['DATA:SOURCE ', channel]);
            
            % Set data format
            obj.writeCommand('DATA:ENC RPB');       % Binary encoding (RPBinary)
            obj.writeCommand('DATA:WIDTH 1');       % 1 byte per data point
        
            % Set number of points (optional, default is max 10000 or 2500 depending on settings)
            obj.writeCommand('DATA:START 1');
            obj.writeCommand('DATA:STOP 10000');    % Adjust if needed
        
            % Acquire data
            obj.writeCommand('ACQUIRE:STATE RUN');  % Start acquisition
        
            pause(duration);                 % Wait to acquire signal
        
            obj.writeCommand('ACQUIRE:STATE STOP'); % Stop acquisition
        
            % Read waveform preamble to interpret binary data
            xincr = str2double(obj.query('WFMPRE:XINCR?'));  % Time increment
            xzero = str2double(obj.query('WFMPRE:XZERO?'));  % Time offset
            ymult = str2double(obj.query('WFMPRE:YMULT?'));  % Y scale factor
            yzero = str2double(obj.query('WFMPRE:YZERO?'));  % Y zero offset
            yoff  = str2double(obj.query('WFMPRE:YOFF?'));   % Y offset
        
            % Request waveform data
            obj.writeCommand('CURVE?');
            raw = readbinblock(obj.Device, "uint8");
        
            % Parse binary block
            % headerLength = 2 + str2double(raw(2));  % e.g., #41000 means 4-digit length
            % dataStart = headerLength + 1;
            % binData = uint8(raw(dataStart:end));    % Extract binary waveform
        
            % Convert to voltage
            voltage = (double(raw) - yoff) * ymult + yzero;
            nPoints = numel(voltage);
            time = xzero + (0:nPoints-1) * xincr;
        end
    end
end