// Copyright 2018 Stephan Tolksdorf

@import UIKit;

void drawUsingSTUTextFrame(NSAttributedString *, CGSize, CGPoint offset);

void drawUsingNSStringDrawing(NSAttributedString *, CGSize, CGPoint offset);

void measureAndDrawUsingNSStringDrawing(NSAttributedString *, CGSize, CGPoint offset);

void drawUsingTextKit(NSAttributedString *, CGSize, CGPoint offset);

void drawUsingCTLine(NSAttributedString *, CGSize, CGPoint offset);

void drawUsingCTTypesetter(NSAttributedString *, CGSize, CGPoint offset);

void drawUsingCTFrame(NSAttributedString *, CGSize, CGPoint offset);
