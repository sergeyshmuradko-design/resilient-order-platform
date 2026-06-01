package com.example.orderservice.controller;

import java.time.Instant;
import java.util.List;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.orderservice.dto.LoginRequest;
import com.example.orderservice.dto.TokenResponse;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;


@RestController
@RequestMapping("/auth")
public class AuthController {
    
    private final UserDetailsService userDetailsService;
    private final PasswordEncoder passwordEncoder;
    private final JwtEncoder jwtEncoder;

    public AuthController(
        UserDetailsService userDetailsService,
        PasswordEncoder passwordEncoder,
        JwtEncoder jwtEncoder
    ) {
        this.userDetailsService = userDetailsService;
        this.passwordEncoder = passwordEncoder;
        this.jwtEncoder = jwtEncoder;
    }

    @PostMapping("/token")
    public TokenResponse token(@RequestBody LoginRequest request) {
        UserDetails user = userDetailsService.loadUserByUsername(request.username());

        if (!passwordEncoder.matches(request.password(), user.getPassword())) {
            throw new IllegalArgumentException("Invalid username or password");
        }

        Instant now = Instant.now();
        long expiresIn = 3600;

        List<String> roles = user.getAuthorities().stream()
            .map(GrantedAuthority::getAuthority)
            .map(authority -> authority.replace("ROLE_", ""))
            .toList();

        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer("resilient-order-platform")
            .issuedAt(now)
            .expiresAt(now.plusSeconds(expiresIn))
            .subject(user.getUsername())
            .claim("roles", roles)
            .build();

        // String token = jwtEncoder.encode(JwtEncoderParameters.from(claims))
        //     .getTokenValue();
        JwsHeader jwsHeader = JwsHeader.with(MacAlgorithm.HS256).build();
        String token = jwtEncoder.encode(JwtEncoderParameters.from(jwsHeader, claims))
            .getTokenValue();

        return new TokenResponse(token, "Bearer", expiresIn);
    }
    
}
