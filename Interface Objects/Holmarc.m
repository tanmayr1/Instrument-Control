classdef Holmarc
    % Demo class to interface with the Holmarc XY Stage
    properties (Access = private)
        stage % serial-port obj containing stage's address
    end

    methods
        % Constructor
        function s = Holmarc(port)
            % Initialize serial port (19200 baud, 8N1):contentReference[oaicite:3]{index=3}
            s = serialport(port, 19200, 'DataBits', 8, 'Parity', 'none', 'StopBits', 1);
            configureTerminator(s, "CR/LF");  % assume CR/LF as line terminator (adjust if needed)
        end
        
        % Function to send move command to axis A (or B)
        function moveAxis(s, axisID, distance_mm)
            % Convert distance (mm) to steps using 0.390625 mm/step
            steps = round(distance_mm / 0.390625);
            if steps < 0
                % If negative, use two's complement for 24-bit
                steps = steps + 2^24;
            end
            % Split into three bytes (big-endian: high, mid, low)【original VI uses 65536, 256】
            highByte = floor(steps / 65536);
            midByte  = floor(mod(steps, 65536) / 256);
            lowByte  = mod(steps, 256);
            % Build command: [AxisID, highByte, midByte, lowByte]
            cmd = uint8([axisID, highByte, midByte, lowByte]);
            % Write bytes to COM port
            write(s, cmd, 'uint8');
            % (The original LabVIEW VI used a similar byte-array command cluster for each move)
        end
        
        % Convenience functions for Axis A (ID=1) and Axis B (ID=2)
        function moveA(s, distance_mm)
            moveAxis(s, 1, distance_mm);
            % Inline comment: This corresponds to writing the A-axis command cluster in the VI.
        end
        
        function moveB(s, distance_mm)
            moveAxis(s, 2, distance_mm);
            % Inline comment: This corresponds to writing the B-axis command cluster in the VI.
        end
        
        % STOP command for an axis (placeholder byte 0xAA used as example)
        function stopAxis(s)
            stopCmd = uint8(170);  % 0xAA as STOP command (from VI logic, stop flag)
            write(s, stopCmd, 'uint8');
            % Inline comment: In LabVIEW VI, a STOP boolean sent a stop code (e.g. 170) to the controller.
        end
        
        % RESET command for an axis (example; actual code may vary)
        function resetAxis(s)
            resetCmd = uint8(171);  % placeholder (e.g. 0xAB) for RESET
            write(s, resetCmd, 'uint8');
            % Inline comment: LabVIEW VI had a RESET button; here we send a reset code (if documented).
        end
        
        % Example usage:
        % moveA(s, 10.0);    % Move Axis A by +10.0 mm
        % moveB(s, -5.0);    % Move Axis B by –5.0 mm
        % stopAxis(s);       % Stop motion on the active axis
        % resetAxis(s);      % Reset position (as per controller’s protocol)

    end
end