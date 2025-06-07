classdef Keithley_2450 < handle
% Keithley_2450 Class to interface with keithley sourcemeter and perform basic operations like measure voltage and current

    properties (Access = private)
        dev % visadev object
    end

    methods
        function obj = Keithley_2450(resourceName)
            % Constructor: Connect to instrument via visadev
            try
                obj.dev = visadev(resourceName);
                configureTerminator(obj.dev, "LF");
                fprintf('Connected to Keithley 2450 at %s\n', resourceName);
            catch ME
                error('Failed to connect via visadev: %s', ME.message);
            end
        end

        function delete(obj)
            % Destructor: Clean up
            if ~isempty(obj.dev)
                clear obj.dev;
                fprintf('Connection to Keithley 2450 closed.\n');
            end
        end

        function sendCommand(obj, command)
            % Send a SCPI command
            % writeline(obj.dev, command);
            write(obj.dev, command);
        end

        function response = query(obj, command)
            % Send a SCPI query and return response
            % response = readline(obj.dev);
            response = writeread(obj.dev, command);
            response = strtrim(response);
        end

        function idn = identify(obj)
            % Return *IDN?
            idn = obj.query('*IDN?');
        end

        function setVoltageSource(obj, voltage)
            % Set voltage source mode and value
            
            obj.sendCommand(sprintf(':SOUR:VOLT %g', voltage));
        end

        function setCurrentSource(obj, current)
            % Set current source mode and value
            obj.sendCommand(':SOUR:FUNC CURR');
            obj.sendCommand(sprintf(':SOUR:CURR %g', current));
        end

        function setCurrentCompLimit(obj, currentLimit)
            % Set current limit (compliance) when sourcing voltage
            obj.sendCommand(sprintf([':SOUR:VOLT:ILIM ', currentLimit]));
        end

        function setVoltageCompLimit(obj, voltageLimit)
            % Set voltage limit (compliance) when sourcing current
            obj.sendCommand(sprintf(':SOUR:CURR:VLIM %g', voltageLimit));
        end

        function setVoltageLimit(obj, voltageLimit)
            % Set Max voltage limit
            obj.sendCommand(sprintf(':SENS:VOLT:RANGE %g', voltageLimit));
        end

        function setCurrentLimit(obj, currentLimit)
            % Set Max current limit
            obj.sendCommand(sprintf([':SENS:CURR:RANGE ', currentLimit]));
        end
        function enableOutput(obj, enable)
            % Enable or disable output
            if enable
                obj.sendCommand(':OUTP ON');
            else
                obj.sendCommand(':OUTP OFF');
            end
        end

        function val = measureCurrent(obj)
            % Measure current (in voltage source mode)
            val = str2double(obj.query(':MEAS:CURR?'));
        end

        function val = measureVoltage(obj)
            % Measure voltage (in current source mode)
            val = str2double(obj.query(':MEAS:VOLT?'));
        end
    end
end