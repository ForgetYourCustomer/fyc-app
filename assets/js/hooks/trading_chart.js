import { Chart } from 'chart.js/auto';
import {
  TimeScale,
  TimeSeriesScale,
} from 'chart.js';
import 'chartjs-adapter-date-fns';

Chart.register(TimeScale, TimeSeriesScale);

export default {
  mounted() {
    console.log("Trading chart hook mounted");
    this.initChart();
  },

  initChart() {
    try {
      const ctx = this.el.getContext('2d');
      const trades = JSON.parse(this.el.dataset.trades || '[]');
      console.log("Initial trades data:", trades);

      // Convert trades to time-based points
      const points = trades.map(trade => ({
        x: new Date(trade.executed_at),  // Use executed_at from the server
        y: trade.price
      }));

      this.chart = new Chart(ctx, {
        type: 'line',
        data: {
          datasets: [{
            label: 'Trade Price',
            data: points,
            borderColor: '#4C51BF',
            backgroundColor: 'rgba(76, 81, 191, 0.1)',
            borderWidth: 2,
            pointRadius: 3,
            pointHoverRadius: 5,
            fill: true
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          animation: false,
          scales: {
            x: {
              type: 'time',
              time: {
                unit: 'minute',
                displayFormats: {
                  minute: 'HH:mm',
                  hour: 'HH:mm'
                }
              },
              title: {
                display: true,
                text: 'Time'
              },
              ticks: {
                maxTicksLimit: 10, // Limit to 10 ticks
                source: 'auto',
                autoSkip: true,
                maxRotation: 0
              }
            },
            y: {
              title: {
                display: true,
                text: 'Price (USDT)'
              },
              ticks: {
                callback: function(value) {
                  return value.toLocaleString();
                }
              }
            }
          },
          plugins: {
            legend: {
              display: false
            },
            tooltip: {
              mode: 'index',
              intersect: false,
              callbacks: {
                label: function(context) {
                  return `Price: ${context.raw.y.toLocaleString()} USDT`;
                }
              }
            }
          }
        }
      });
    } catch (error) {
      console.error("Error initializing chart:", error);
    }
  },

  updated() {
    try {
      const trades = JSON.parse(this.el.dataset.trades || '[]');
      console.log("Updating chart with trades:", trades);
      
      if (this.chart) {
        const points = trades.map(trade => ({
          x: new Date(trade.executed_at),  // Use executed_at from the server
          y: trade.price
        }));
        
        this.chart.data.datasets[0].data = points;
        this.chart.update();
      }
    } catch (error) {
      console.error("Error updating chart:", error);
    }
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};
