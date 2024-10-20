const webpack = require('webpack');
const { override, addWebpackAlias } = require('customize-cra');
const path = require('path');

module.exports = override(
    addWebpackAlias({
        buffer: path.resolve(__dirname, 'node_modules/buffer/')
    }),
    config => {
        config.resolve.fallback = {
            buffer: require.resolve('buffer/'),
        };
        config.plugins.push(
            new webpack.ProvidePlugin({
                Buffer: ['buffer', 'Buffer'],
            })
        );
        return config;
    }
);