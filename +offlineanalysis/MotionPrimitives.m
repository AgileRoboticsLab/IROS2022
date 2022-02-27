% ==================== MotionPrimitives =======================
%
%  Subclass of the ExperimentalData class specific to experiments
%  exhuastively exploring motion primitives using Euler tours.
% 
%
%  MotionPrimitives()
%
%
% ==================== MotionPrimitives =======================
classdef MotionPrimitives < offlineanalysis.ExperimentalData 
    properties (Access = public)
     % Subclass-specific properties
      n_unique_states;     % number of unique robot states
      
      robo_states;         % sequence of robot states e.g., [1, 7, 16, ...]
                           % This will be a [1 x 241] vector corresponding to
                           % randomized Euler tour.
      primitive_labels;    % sequence of robot motion primitive labels, 
                           % e.g., [161, 23, 1, ...] for = {1,2, ..., 240}
      
    end 
    
    methods
        % Constructor
        function this = MotionPrimitives( raw_data, params, Euler_tour)

          this@offlineanalysis.ExperimentalData( raw_data, params ); % super class constructor
          this.set_property(params, 'n_unique_states', 16);
          this.robo_states = Euler_tour;
          
          this.states_to_primitives;
        end
        
    
        % Set parameter value for class-instance, based on user specified 
        % values (or default if property doesn't exist as struct field)
        function set_property(this, source_struct, param_name, def_val)
          if ( isfield(source_struct, param_name) )
            this.(param_name) = source_struct.(param_name);
          else
            this.(param_name) = def_val;
          end
        end
        
        % Convert the 241 roobot state sequence into a sequence of motion 
        % primitive labels.
        function states_to_primitives(this)
            states = this.robo_states;
            n_states = this.n_unique_states;
            for i = 1:length(states)-1
                this.primitive_labels(i) = inverse_map(states(i), states(i+1), n_states);
            end
            function edgeNum = inverse_map(from,to,n_states)
         % n_s = number of states (in our case, 16)
           for m = 2:n_states-1
               h(m-1) = H(f(from,to,n_states)-f(m,m,n_states));
           end
           edgeNum = f(from,to,n_states)-sum(h);
           
           % Nested helper function 1
           function F = f(i,j,n_states)
                F = n_states*(i-1)+(j-1);
           end
           % Nested helper function 2
           function h = H(x)     % discrete Heaviside step function
               if x <0
                   h = 0;
               else
                   h = 1;
               end
           
           end
           end
        end
        
    end

end