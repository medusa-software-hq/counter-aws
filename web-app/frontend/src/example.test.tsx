import { Button } from '@mantine/core';
import { render, screen } from '@test-utils';

// The custom `render` from `@test-utils` wraps components in MantineProvider.
test('renders a Mantine component through the test harness', () => {
  render(<Button>Click me</Button>);
  expect(screen.getByRole('button', { name: 'Click me' })).toBeInTheDocument();
});
