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
    },
    Paper: {
      defaultProps: {
        shadow: 'sm',
        withBorder: true,
        p: 'lg',
      },
    },
  },
}); 