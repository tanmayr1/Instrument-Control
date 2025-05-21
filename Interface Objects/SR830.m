classdef SR830 < handle
    % SR830 Class for interfacing with SR830 lock-in amplifier. This class provides methods to connect to an SR830 lock-in amplifier, configure it, and perform voltage drop measurements.
    
    properties
        % Hardware connection
        Device
        
        % Configuration parameters
        GPIBAddress = 8            % Default GPIB address for SR830
        NumMeasurements = 100      % Number of measurements to take
        MeasurementInterval = 0.5  % Time between measurements (seconds)
        OutputFilename = 'voltage_drop_data.csv'  % Output file name
        
        % Measurement data
        VoltageData
        StartTime
        
        % Plot handles
        FigureHandle
        PlotHandle
    end
    
    methods
        function obj = SR830(address)
            % Constructor: Initialize the SR830 connection
            % Input: address - Optional GPIB address (default=8)
            
            if nargin > 0
                obj.GPIBAddress = address;
            end
            
            % Initialize data storage
            obj.VoltageData = [];
        end
        
        function connect(obj)
            % Connect to the SR830 lock-in amplifier
            try
                % Create VISA device object using visadev
                obj.Device = visadev(['GPIB0::' num2str(obj.GPIBAddress) '::INSTR']);
                
                % For USB connection, use something like:
                % obj.Device = visadev('USB0::0x0B6A::0x0100::INSTR');
                
                % Configure communication properties
                obj.Device.ByteOrder = 'littleEndian';
                obj.Device.Timeout = 10; % 10 seconds timeout
                
                disp('Successfully connected to SR830');
            catch ME
                error('Failed to connect to SR830: %s', ME.message);
            end
        end
        
        function disconnect(obj)
            % Disconnect from the SR830
            try
                if ~isempty(obj.Device)
                    clear obj.Device;
                    obj.Device = [];
                    disp('Disconnected from SR830');
                end
            catch
                warning('Error disconnecting from SR830');
            end
        end
        
        function configure(obj, varargin)
            % Configure the SR830 with standard or custom parameters
            % Optional inputs: Name-value pairs for configuration parameters
            
            % Process optional arguments
            if nargin > 1
                for i = 1:2:length(varargin)
                    switch lower(varargin{i})
                        case 'frequency'
                            frequency = varargin{i+1};
                        case 'amplitude'
                            amplitude = varargin{i+1};
                        case 'sensitivity'
                            sensitivity = varargin{i+1};
                        case 'timeconstant'
                            timeConstant = varargin{i+1};
                        otherwise
                            warning('Unknown parameter: %s', varargin{i});
                    end
                end
            end
            
            % Default parameters if not specified
            if ~exist('frequency', 'var'), frequency = 1000; end
            if ~exist('amplitude', 'var'), amplitude = 1.0; end
            if ~exist('sensitivity', 'var'), sensitivity = 22; end
            if ~exist('timeConstant', 'var'), timeConstant = 10; end
            
            try
                % Initialize with standard parameters
                writeline(obj.Device, '*RST');                     % Reset to default configuration
                writeline(obj.Device, ['FREQ ' num2str(frequency)]); % Set reference frequency
                writeline(obj.Device, ['SLVL ' num2str(amplitude)]); % Set sine output amplitude
                writeline(obj.Device, ['SENS ' num2str(sensitivity)]); % Set sensitivity
                writeline(obj.Device, ['OFLT ' num2str(timeConstant)]); % Set time constant
                writeline(obj.Device, 'FMOD 1');                   % Internal reference source
                writeline(obj.Device, 'ISRC 0');                   % Current input off
                writeline(obj.Device, 'IGND 0');                   % Input shield grounded
                writeline(obj.Device, 'ICPL 0');                   % Input coupling AC
                writeline(obj.Device, 'DDEF 1,0,0');               % CH1 display R, No ratio
                writeline(obj.Device, 'DDEF 2,1,0');               % CH2 display θ, No ratio
                
                % Wait for settings to take effect
                pause(2);
                disp('SR830 configured successfully');
            catch ME
                error('Error configuring SR830: %s', ME.message);
            end
        end
        
        function initializeMeasurement(obj, numMeasurements, interval)
            % Initialize measurement parameters and prepare for data collection
            % Inputs:
            %   numMeasurements - Number of measurements to take (optional)
            %   interval - Time between measurements in seconds (optional)
            
            if nargin > 1, obj.NumMeasurements = numMeasurements; end
            if nargin > 2, obj.MeasurementInterval = interval; end
            
            % Initialize data storage
            obj.VoltageData = zeros(obj.NumMeasurements, 3); % [time, X, Y]
            obj.StartTime = datetime("now");
            
            % Create figure for real-time plotting
            obj.FigureHandle = figure;
            hold on;
            obj.PlotHandle = plot(NaN, NaN, 'b-', 'LineWidth', 1.5);
            xlabel('Time (s)');
            ylabel('Voltage (V)');
            title('SR830 Voltage Measurement');
            grid on;
            drawnow;
        end
        
        function [X, Y] = measure(obj)
            % Take a single measurement from the SR830
            % Returns: X, Y voltage components
            
            try
                % Measure X and Y components
                writeline(obj.Device, 'SNAP? 1,2');
                response = readline(obj.Device);
                data = str2double(response);
                X = data(1);
                Y = data(2);
            catch ME
                warning(['Error taking measurement: %s', ME.message]);
                X = NaN;
                Y = NaN;
            end
        end
        
        function [R, theta] = measurePolar(obj)
            % Take a single measurement in polar form from the SR830
            % Returns: R (magnitude), theta (phase)
            
            try
                % Measure R and theta components
                writeline(obj.Device, 'SNAP? 3,4');
                response = readline(obj.Device);
                data = str2double(response);
                R = data(1);
                theta = data(2);
            catch ME
                warning(['Error taking measurement: %s', ME.message]);
                R = NaN;
                theta = NaN;
            end
        end
        
        function startMeasurementSequence(obj)
            % Perform a sequence of measurements
            
            disp('Starting measurements...');
            for i = 1:obj.NumMeasurements
                % Get current time
                currentTime = (datetime("now") - obj.StartTime) * 24 * 3600; % Convert to seconds
                
                % Measure voltage
                [X, Y] = obj.measure();
                
                % Store data
                obj.VoltageData(i, 1) = currentTime;
                obj.VoltageData(i, 2) = X;
                obj.VoltageData(i, 3) = Y;
                
                % Update plot
                set(obj.PlotHandle, 'XData', obj.VoltageData(1:i, 1), 'YData', obj.VoltageData(1:i, 2));
                drawnow;
                
                % Display current values
                fprintf('Measurement %d of %d: Time = %.2f s, X = %.6f V, Y = %.6f V\n', ...
                    i, obj.NumMeasurements, currentTime, X, Y);
                
                % Wait for next measurement
                pause(obj.MeasurementInterval);
            end
            
            disp('Measurement sequence completed successfully.');
        end
        
        function saveData(obj, filename)
            % Save measurement data to CSV file
            % Input: filename - Optional custom filename
            
            if nargin > 1, obj.OutputFilename = filename; end
            
            disp(['Saving data to ' obj.OutputFilename]);
            
            % Prepare headers and data
            headers = {'Time(s)', 'X(V)', 'Y(V)'};
            outputData = [headers; num2cell(obj.VoltageData)];
            
            % Write to CSV file
            writecell(outputData, obj.OutputFilename);
            disp('Data saved successfully');
        end
        
        function plotResults(obj)
            % Create final plots of the results
            
            figure;
            subplot(2,1,1);
            plot(obj.VoltageData(:,1), obj.VoltageData(:,2), 'b-', 'LineWidth', 1.5);
            xlabel('Time (s)');
            ylabel('X Component (V)');
            title('SR830 X Component Measurement');
            grid on;
            
            subplot(2,1,2);
            plot(obj.VoltageData(:,1), obj.VoltageData(:,3), 'r-', 'LineWidth', 1.5);
            xlabel('Time (s)');
            ylabel('Y Component (V)');
            title('SR830 Y Component Measurement');
            grid on;
        end
    end
end