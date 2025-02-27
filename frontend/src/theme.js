import { createTheme } from '@mantine/core';

export const theme = createTheme({
  primaryColor: 'orange',
  defaultRadius: 'md',
  colors: {
    // Custom color palette
    dark: [
      '#C1C2C5',
      '#A6A7AB',
      '#909296',
      '#5c5f66',
      '#373A40',
      '#2C2E33',
      '#25262b',
      '#1A1B1E',
      '#141517',
      '#101113',
    ],
    orange: [
      '#fff4e6',
      '#ffe8cc',
      '#ffd8a8',
      '#ffc078',
      '#ffa94d',
      '#ff922b',
      '#fd7e14',
      '#f76707',
      '#e8590c',
      '#d9480f',
    ]
  },
  components: {
    Button: {
      defaultProps: {
        radius: 'xl',
      },
    },
    ActionIcon: {
      defaultProps: {
        variant: 'subtle',
      },
      styles: {
        root: {
          '&[data-variant="subtle"][data-color="orange"]': {
            color: '#ff922b',
            '& svg': {
              color: '#ff922b !important',
              fill: 'currentColor',
            }
          },
          '&[data-variant="filled"][data-color="orange"]': {
            backgroundColor: '#ff922b',
            color: 'white',
            '& svg': {
              color: 'white !important',
              fill: 'currentColor',
            }
          }
        }
      }
    },
    Paper: {
      defaultProps: {
        shadow: 'sm',
        withBorder: true,
        p: 'lg',
      },
    },
    Text: {
      defaultProps: {
        c: 'white',
      },
    },
    Title: {
      defaultProps: {
        c: 'white',
      },
    },
  },
  // Ensure consistent text colors in dark mode
  other: {
    fontColor: '#ffffff',
    dimmedColor: '#909296',
  },
}); 