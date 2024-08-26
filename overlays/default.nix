final: prev: {

quarto = prev.quarto.override {
    extraPythonPackages = ps: with ps; [
      plotly
      numpy
      pandas
      matplotlib
      tabulate
    ];
  };
    
};

